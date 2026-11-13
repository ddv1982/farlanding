extends GutTest
## SignalPulses: which discovery sites pulse, and the scan loop's lifecycle.
## Sites are stubs with the duck-typed properties of the gameplay contract.


class FakeSite:
	extends Node3D
	var is_resolved: bool = false
	var is_being_scanned: bool = false
	var discovery_type: StringName = &"geological"
	var is_visible_to_player: bool = false
	var is_signal_known_to_player: bool = true


## A site that says nothing about what the player knows.
class FakeMuteSite:
	extends Node3D
	var is_resolved: bool = false


class FakeScanner:
	extends Node3D
	var faction: int = 0


var _pulses: SignalPulses
var _events: Dictionary[StringName, SoundEvent] = {}
var _one_shots: Array[Array] = []


func before_each() -> void:
	_one_shots.clear()
	_events.clear()
	_events[DiscoveryCues.PULSE] = _event(DiscoveryCues.PULSE, "signal_pulse", 3, 80.0)
	_events[DiscoveryCues.SCAN_LOOP] = _event(DiscoveryCues.SCAN_LOOP, "scan_loop", 3, 120.0)
	_pulses = SignalPulses.new()
	_pulses.resolve_event = func(id: StringName) -> SoundEvent: return _events.get(id, null)
	_pulses.play_at = func(id: StringName, at: Vector3) -> bool:
		_one_shots.append([id, at])
		return true
	add_child_autofree(_pulses)


func _event(id: StringName, file: String, cap: int, reach: float) -> SoundEvent:
	var event: SoundEvent = SoundEvent.new()
	event.id = id
	event.streams = [load("res://assets/audio/discovery/%s.wav" % file) as AudioStream]
	event.max_instances = cap
	event.max_distance = reach
	event.positional = true
	event.bus = &"Discovery"
	return event


func _site(at: Vector3, node: Node3D = null) -> Node3D:
	var site: Node3D = node if node != null else FakeSite.new()
	site.add_to_group(DiscoveryCues.SITES_GROUP)
	add_child_autofree(site)
	site.global_position = at
	return site


func _scanner(faction: int = 0) -> FakeScanner:
	var scanner: FakeScanner = FakeScanner.new()
	scanner.faction = faction
	add_child_autofree(scanner)
	return scanner


func test_wants_pulse_reads_the_contract() -> void:
	var site: FakeSite = FakeSite.new()
	assert_true(DiscoveryCues.wants_pulse(site), "known and unresolved")
	site.is_signal_known_to_player = false
	assert_false(DiscoveryCues.wants_pulse(site), "unknown to the player")
	site.is_signal_known_to_player = true
	site.is_resolved = true
	assert_false(DiscoveryCues.wants_pulse(site), "resolved")
	site.is_resolved = false
	site.is_being_scanned = true
	assert_false(DiscoveryCues.wants_pulse(site), "being scanned")
	var mute: FakeMuteSite = FakeMuteSite.new()
	assert_false(DiscoveryCues.wants_pulse(mute), "no knowledge property: silent")
	site.free()
	mute.free()


func test_only_known_unresolved_sites_pulse_nearest_first() -> void:
	var far: Node3D = _site(Vector3(40, 0, 0))
	var near: Node3D = _site(Vector3(5, 0, 0))
	var unknown: FakeSite = _site(Vector3(1, 0, 0)) as FakeSite
	unknown.is_signal_known_to_player = false
	var resolved: FakeSite = _site(Vector3(2, 0, 0)) as FakeSite
	resolved.is_resolved = true
	_site(Vector3(3, 0, 0), FakeMuteSite.new())
	_pulses.rescan()
	assert_eq(_pulses.chosen_sites(), [near, far] as Array[Node3D])


func test_pulses_are_capped_and_out_of_range_sites_are_silent() -> void:
	var expected: Array[Node3D] = []
	for i: int in 5:
		var site: Node3D = _site(Vector3(10 + i, 0, 0))
		if i < SignalPulses.MAX_PULSES:
			expected.append(site)
	_site(Vector3(500, 0, 0))
	_pulses.rescan()
	assert_eq(_pulses.chosen_sites(), expected, "MAX_PULSES nearest")
	_events[DiscoveryCues.PULSE].max_instances = 1
	_pulses.rescan()
	assert_eq(_pulses.chosen_sites().size(), 1, "event max_instances")
	_pulses.focus = Vector3(1000, 0, 0)
	_pulses.rescan()
	assert_eq(_pulses.chosen_sites().size(), 0, "beyond max_distance")


func test_pulse_players_start_and_fade_out() -> void:
	var site: FakeSite = _site(Vector3(5, 0, 0)) as FakeSite
	_pulses.rescan()
	assert_eq(_pulses.playing_count(), 1)
	site.is_resolved = true
	_pulses.rescan()
	for i: int in 10:
		_pulses._process(0.2)
	assert_eq(_pulses.playing_count(), 0, "faded out once resolved")


func test_scan_loop_replaces_the_pulse_and_stops_on_interruption() -> void:
	var site: FakeSite = _site(Vector3(5, 0, 0)) as FakeSite
	_pulses.rescan()
	assert_eq(_pulses.chosen_sites(), [site] as Array[Node3D])
	var first: FakeScanner = _scanner()
	var second: FakeScanner = _scanner()
	Events.scan_started.emit(first, site)
	Events.scan_started.emit(second, site)
	site.is_being_scanned = true
	assert_true(_pulses.is_scanning(site))
	assert_eq(_pulses.scanning_sites().size(), 1, "one loop per site")
	_pulses.rescan()
	assert_eq(_pulses.chosen_sites().size(), 0, "no pulse while scanned")
	Events.scan_interrupted.emit(first, site)
	assert_true(_pulses.is_scanning(site), "the other scanner carries on")
	assert_eq(_one_shots.size(), 0)
	Events.scan_interrupted.emit(second, site)
	site.is_being_scanned = false
	assert_false(_pulses.is_scanning(site))
	assert_eq(_one_shots, [[DiscoveryCues.SCAN_CUT, Vector3(5, 0, 0)]] as Array[Array])
	_pulses.rescan()
	assert_eq(_pulses.chosen_sites(), [site] as Array[Node3D], "pulses again")


func test_discovery_stops_the_scan_loop_silently() -> void:
	var site: FakeSite = _site(Vector3(5, 0, 0)) as FakeSite
	Events.scan_started.emit(_scanner(), site)
	assert_true(_pulses.is_scanning(site))
	site.is_resolved = true
	Events.discovery_made.emit(site, Resource.new(), 0)
	assert_false(_pulses.is_scanning(site))
	assert_eq(_one_shots.size(), 0, "no cut sound: the resolve phrase takes over")
	_pulses.rescan()
	assert_eq(_pulses.chosen_sites().size(), 0)


func test_enemy_scans_are_heard_only_where_the_player_sees() -> void:
	var hidden: FakeSite = _site(Vector3(5, 0, 0)) as FakeSite
	Events.scan_started.emit(_scanner(1), hidden)
	assert_false(_pulses.is_scanning(hidden), "enemy scan in the fog")
	var seen: FakeSite = _site(Vector3(8, 0, 0)) as FakeSite
	seen.is_visible_to_player = true
	Events.scan_started.emit(_scanner(1), seen)
	assert_true(_pulses.is_scanning(seen))


func test_scan_loop_stops_when_the_site_goes_away_or_resolves_unannounced() -> void:
	var site: FakeSite = _site(Vector3(5, 0, 0)) as FakeSite
	Events.scan_started.emit(_scanner(), site)
	site.is_being_scanned = true
	_pulses.rescan()
	assert_true(_pulses.is_scanning(site), "still scanning")
	site.is_resolved = true
	_pulses.rescan()
	assert_false(_pulses.is_scanning(site), "resolved without an event")
	var other: FakeSite = _site(Vector3(6, 0, 0)) as FakeSite
	Events.scan_started.emit(_scanner(), other)
	other.free()
	_pulses.rescan()
	assert_eq(_pulses.scanning_sites().size(), 0, "freed site")
