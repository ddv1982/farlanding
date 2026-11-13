class_name VentGauge
extends Node3D
## The pressure of an erupting vent (ADR 0015), drawn on the ground round it: a ring
## of twelve segments that fills as the pressure builds, amber while calm, red and
## beating once the eruption is announced or a forecast names this vent the next to
## burst. A countdown floats above it while it is about to erupt. It follows the
## node's `pressure_changed` and `forecast_changed` signals and hides with the node
## under fog. Reads the simulation, never changes it.

const SHADER: Shader = preload("res://presentation/shaders/vent_gauge.gdshader")
const ALARM_COLOR := Color(1.0, 0.42, 0.12)
## Width of the ring, in metres (outside the Tap's footprint).
const SIZE: float = 9.0
## Height of the countdown above the vent, in metres.
const LIFT: float = 3.4

var _ring: MeshInstance3D
var _countdown: Label3D
var _pressure: float = 0.0
var _burst: float = -1.0
var _next: bool = false


static func attach(vent: ResourceNode) -> VentGauge:
	var gauge: VentGauge = VentGauge.new()
	gauge.name = &"VentGauge"
	vent.add_child(gauge)
	vent.pressure_changed.connect(gauge.show_pressure)
	vent.forecast_changed.connect(gauge.show_forecast)
	gauge.show_pressure(vent.pressure, vent.seconds_to_burst)
	gauge.show_forecast(vent.is_next_to_erupt)
	return gauge


func _init() -> void:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHADER
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(SIZE, SIZE)
	quad.orientation = PlaneMesh.FACE_Y
	quad.material = material
	_ring = MeshInstance3D.new()
	_ring.name = &"Ring"
	_ring.mesh = quad
	_ring.position = Vector3(0.0, 0.25, 0.0)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_countdown = Label3D.new()
	_countdown.name = &"Countdown"
	_countdown.position = Vector3(0.0, LIFT, 0.0)
	_countdown.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_countdown.no_depth_test = true
	_countdown.fixed_size = true
	_countdown.pixel_size = 0.0009
	_countdown.font_size = 30
	_countdown.outline_size = 8
	_countdown.modulate = ALARM_COLOR
	_countdown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_countdown)


func show_pressure(pressure: float, seconds_to_burst: float) -> void:
	_pressure = pressure
	_burst = seconds_to_burst
	_refresh()


func show_forecast(next_to_erupt: bool) -> void:
	_next = next_to_erupt
	_refresh()


## What the countdown reads now ("" while the vent is calm), for tests.
func countdown_text() -> String:
	return _countdown.text


func _refresh() -> void:
	var erupting: bool = _burst >= 0.0
	_ring.set_instance_shader_parameter(&"pressure", 1.0 if erupting else _pressure)
	_ring.set_instance_shader_parameter(&"alarm", 1.0 if erupting or _next else 0.0)
	var line: String = ""
	if erupting:
		var left: int = ceili(_burst)
		line = "%d:%02d" % [floori(left / 60.0), left % 60]
	elif _next:
		line = "NEXT"
	_countdown.text = line
	_countdown.visible = line != ""
