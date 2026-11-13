class_name MixScene
extends RefCounted
## Drives scenes through the real `Audio` autoload and bus layout and measures
## what reaches the Master bus (the final mix test, and the numbers in
## docs/AUDIO_STYLE.md). Headless Godot mixes in real time on its Dummy driver,
## so a capture effect on Master hears exactly what a player would.
##
## Two captures: one before the Master limiter (does the mix itself clip?) and
## one after it (what leaves the game). Loudness is BS.1770 K-weighted (shelf
## and high-pass as RBJ biquads at the mix rate), gated at -70 LUFS absolute
## and -10 LU relative over 400 ms blocks with 75 % overlap.

const WEAPONS: Array[StringName] = [
	&"weapon_repeater_fire",
	&"weapon_light_gun_fire",
	&"weapon_cannon_fire",
	&"weapon_skitter_gun_fire",
	&"weapon_lance_fire",
	&"weapon_siege_fire",
	&"weapon_lancer_fire",
	&"weapon_arc_fire",
	&"weapon_sentry_fire",
]
const IMPACTS: Array[StringName] = [&"impact_spark", &"impact_armour", &"impact_ground"]
const BLASTS: Array[StringName] = [
	&"explosion_small",
	&"explosion_medium",
	&"explosion_large",
	&"death_light",
	&"death_heavy",
	&"death_building",
	&"death_prop_tank",
]
const ALERTS: Array[StringName] = [
	&"advisor_under_attack", &"stealth_alert_alarm", &"advisor_storm_warning", &"stealth_spotted"
]
const BUSES: Array[StringName] = [
	&"Master",
	&"Music",
	&"Ambience",
	&"Weather",
	&"SFX",
	&"Weapons",
	&"Explosions",
	&"Voice",
	&"Advisor",
	&"UI",
	&"Stealth",
	&"Discovery",
]

## The low band checked under the Advisor (Hz).
const LOW_BAND_HZ: float = 150.0

var pre: AudioEffectCapture
var post: AudioEffectCapture
## Bus -> capture at the end of its effect chain (before its fader), for
## per-category loudness.
var bus_captures: Dictionary[StringName, AudioEffectCapture] = {}
## Highest per-bus peak meter reading (dBFS) seen while recording.
var bus_peaks: Dictionary[StringName, float] = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 6006


## Adds the two captures to Master (pre and post limiter).
func attach() -> void:
	pre = AudioEffectCapture.new()
	pre.buffer_length = 10.0
	post = AudioEffectCapture.new()
	post.buffer_length = 10.0
	AudioServer.add_bus_effect(0, pre, 0)
	AudioServer.add_bus_effect(0, post, -1)


## Adds a capture at the end of `bus`'s effect chain.
func attach_bus(bus: StringName) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var capture: AudioEffectCapture = AudioEffectCapture.new()
	capture.buffer_length = 10.0
	AudioServer.add_bus_effect(index, capture, -1)
	bus_captures[bus] = capture


func detach() -> void:
	for bus_index: int in AudioServer.bus_count:
		for i: int in range(AudioServer.get_bus_effect_count(bus_index) - 1, -1, -1):
			var effect: AudioEffect = AudioServer.get_bus_effect(bus_index, i)
			var ours: bool = effect == pre or effect == post
			for capture: AudioEffectCapture in bus_captures.values():
				ours = ours or effect == capture
			if ours:
				AudioServer.remove_bus_effect(bus_index, i)
	bus_captures.clear()


func clear() -> void:
	if pre != null:
		pre.clear_buffer()
		post.clear_buffer()
	for capture: AudioEffectCapture in bus_captures.values():
		capture.clear_buffer()
	bus_peaks.clear()


## One frame of a worst-case battle near the listener: up to `shots` weapon
## starts, impacts, now and then a blast; the voice budget decides what plays.
func battle_frame(shots: int) -> void:
	for i: int in shots:
		var at: Vector3 = _around(4.0, 35.0)
		Audio.play_at(WEAPONS[_rng.randi() % WEAPONS.size()], at)
		Audio.play_at(IMPACTS[_rng.randi() % IMPACTS.size()], _around(4.0, 35.0))
	if _rng.randf() < 0.18:
		Audio.play_at(BLASTS[_rng.randi() % BLASTS.size()], _around(3.0, 25.0))


func alert(index: int) -> void:
	Audio.play(ALERTS[index % ALERTS.size()])


func note_bus_peaks() -> void:
	for bus: StringName in BUSES:
		var index: int = AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		var peak: float = maxf(
			AudioServer.get_bus_peak_volume_left_db(index, 0),
			AudioServer.get_bus_peak_volume_right_db(index, 0)
		)
		var before: float = bus_peaks.get(bus, -200.0)
		bus_peaks[bus] = maxf(before, peak)


static func frames_of(capture: AudioEffectCapture) -> PackedVector2Array:
	return capture.get_buffer(capture.get_frames_available())


static func peak_dbfs(frames: PackedVector2Array) -> float:
	var peak: float = 0.0
	for frame: Vector2 in frames:
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	return linear_to_db(peak) if peak > 0.0 else -200.0


## Integrated loudness (LUFS) of stereo frames at `rate`.
static func lufs(frames: PackedVector2Array, rate: float) -> float:
	var shelf: PackedFloat64Array = _biquad_shelf(rate)
	var hp: PackedFloat64Array = _biquad_highpass(rate)
	var weighted: PackedFloat64Array = PackedFloat64Array()
	weighted.resize(frames.size())
	for channel: int in 2:
		var s1: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0]
		var s2: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0]
		for i: int in frames.size():
			var x: float = frames[i].x if channel == 0 else frames[i].y
			var y: float = _run(shelf, s1, x)
			var z: float = _run(hp, s2, y)
			weighted[i] += z * z
	var block: int = int(0.4 * rate)
	var hop: int = block / 4
	var energies: PackedFloat64Array = []
	var start: int = 0
	while start + block <= weighted.size():
		var total: float = 0.0
		for i: int in range(start, start + block):
			total += weighted[i]
		energies.append(total / block)
		start += hop
	var gated: PackedFloat64Array = []
	for e: float in energies:
		if e > 0.0 and -0.691 + 10.0 * log(e) / log(10.0) > -70.0:
			gated.append(e)
	if gated.is_empty():
		return -200.0
	var mean: float = 0.0
	for e: float in gated:
		mean += e
	mean /= gated.size()
	var relative: float = -0.691 + 10.0 * log(mean) / log(10.0) - 10.0
	var kept: float = 0.0
	var count: int = 0
	for e: float in gated:
		if -0.691 + 10.0 * log(e) / log(10.0) > relative:
			kept += e
			count += 1
	return -0.691 + 10.0 * log(kept / maxi(count, 1)) / log(10.0)


## Loudness (LUFS) of `a` and of `b` over only the 400 ms blocks where `a` is
## sounding (within 10 LU of its loudest block): "is the Advisor above the
## music *while it speaks*". Returns [a, b].
static func loudness_while(
	a: PackedVector2Array, b: PackedVector2Array, rate: float
) -> Array[float]:
	var ea: PackedFloat64Array = block_energies(a, rate)
	var eb: PackedFloat64Array = block_energies(b, rate)
	var loudest: float = 0.0
	for e: float in ea:
		loudest = maxf(loudest, e)
	var sum_a: float = 0.0
	var sum_b: float = 0.0
	var count: int = 0
	for i: int in mini(ea.size(), eb.size()):
		if loudest > 0.0 and ea[i] >= loudest * 0.1:
			sum_a += ea[i]
			sum_b += eb[i]
			count += 1
	if count == 0:
		return [-200.0, -200.0]
	return [_to_lufs(sum_a / count), _to_lufs(sum_b / count)]


## Unweighted level (dB RMS) of `b` below LOW_BAND_HZ and of `a` (full band),
## over only the 400 ms blocks where `a` is sounding: "does the score's low end
## sit under the Advisor while it speaks". Returns [b low, a].
static func low_band_while(
	a: PackedVector2Array, b: PackedVector2Array, rate: float
) -> Array[float]:
	var ea: PackedFloat64Array = _plain_energies(a, rate, PackedFloat64Array())
	var eb: PackedFloat64Array = _plain_energies(b, rate, _biquad_lowpass(rate, LOW_BAND_HZ))
	var loudest: float = 0.0
	for e: float in ea:
		loudest = maxf(loudest, e)
	var sum_a: float = 0.0
	var sum_b: float = 0.0
	var count: int = 0
	for i: int in mini(ea.size(), eb.size()):
		if loudest > 0.0 and ea[i] >= loudest * 0.1:
			sum_a += ea[i]
			sum_b += eb[i]
			count += 1
	if count == 0:
		return [-200.0, -200.0]
	return [_to_db(sum_b / count), _to_db(sum_a / count)]


## K-weighted mean-square energy of 400 ms blocks (no overlap).
static func block_energies(frames: PackedVector2Array, rate: float) -> PackedFloat64Array:
	var shelf: PackedFloat64Array = _biquad_shelf(rate)
	var hp: PackedFloat64Array = _biquad_highpass(rate)
	var block: int = int(0.4 * rate)
	var out: PackedFloat64Array = []
	out.resize(frames.size() / block)
	for channel: int in 2:
		var s1: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0]
		var s2: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0]
		for i: int in out.size() * block:
			var x: float = frames[i].x if channel == 0 else frames[i].y
			var z: float = _run(hp, s2, _run(shelf, s1, x))
			out[i / block] += z * z / block
	return out


## Mean-square energy of 400 ms blocks, through `filter` (a biquad; empty: none).
static func _plain_energies(
	frames: PackedVector2Array, rate: float, filter: PackedFloat64Array
) -> PackedFloat64Array:
	var block: int = int(0.4 * rate)
	var out: PackedFloat64Array = []
	out.resize(frames.size() / block)
	for channel: int in 2:
		var state: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0]
		for i: int in out.size() * block:
			var x: float = frames[i].x if channel == 0 else frames[i].y
			if not filter.is_empty():
				x = _run(filter, state, x)
			out[i / block] += x * x / (2.0 * block)
	return out


static func _to_db(energy: float) -> float:
	return 10.0 * log(energy) / log(10.0) if energy > 0.0 else -200.0


static func _to_lufs(energy: float) -> float:
	return -0.691 + 10.0 * log(energy) / log(10.0) if energy > 0.0 else -200.0


func _around(near: float, far: float) -> Vector3:
	var angle: float = _rng.randf() * TAU
	return Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(near, far)


## Direct form I biquad step; state = [x1, x2, y1, y2].
static func _run(c: PackedFloat64Array, state: PackedFloat64Array, x: float) -> float:
	var y: float = c[0] * x + c[1] * state[0] + c[2] * state[1] - c[3] * state[2] - c[4] * state[3]
	state[1] = state[0]
	state[0] = x
	state[3] = state[2]
	state[2] = y
	return y


## K-weighting stage 1: high shelf +4 dB at 1681.97 Hz (Q 0.7072).
static func _biquad_shelf(rate: float) -> PackedFloat64Array:
	var a: float = pow(10.0, 4.0 / 40.0)
	var w: float = TAU * 1681.974 / rate
	var alpha: float = sin(w) / (2.0 * 0.7072)
	var cw: float = cos(w)
	var sa: float = 2.0 * sqrt(a) * alpha
	var b0: float = a * ((a + 1.0) + (a - 1.0) * cw + sa)
	var b1: float = -2.0 * a * ((a - 1.0) + (a + 1.0) * cw)
	var b2: float = a * ((a + 1.0) + (a - 1.0) * cw - sa)
	var a0: float = (a + 1.0) - (a - 1.0) * cw + sa
	var a1: float = 2.0 * ((a - 1.0) - (a + 1.0) * cw)
	var a2: float = (a + 1.0) - (a - 1.0) * cw - sa
	return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0]


## RBJ low-pass at `fc` (Q 0.7071), for the low-band check.
static func _biquad_lowpass(rate: float, fc: float) -> PackedFloat64Array:
	var w: float = TAU * fc / rate
	var alpha: float = sin(w) / (2.0 * 0.7071)
	var cw: float = cos(w)
	var b1: float = 1.0 - cw
	var a0: float = 1.0 + alpha
	return [b1 / 2.0 / a0, b1 / a0, b1 / 2.0 / a0, -2.0 * cw / a0, (1.0 - alpha) / a0]


## K-weighting stage 2: high-pass at 38.14 Hz (Q 0.5003).
static func _biquad_highpass(rate: float) -> PackedFloat64Array:
	var w: float = TAU * 38.135 / rate
	var alpha: float = sin(w) / (2.0 * 0.5003)
	var cw: float = cos(w)
	var b0: float = (1.0 + cw) / 2.0
	var a0: float = 1.0 + alpha
	return [b0 / a0, -(1.0 + cw) / a0, b0 / a0, -2.0 * cw / a0, (1.0 - alpha) / a0]
