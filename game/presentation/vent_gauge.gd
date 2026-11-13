class_name VentGauge
extends Label3D
## PLACEHOLDER look of an erupting vent's pressure (ADR 0015), until the lead's art
## replaces it: a billboard line above the vent, "PRESSURE 70%", "ERUPTING 0:08", and
## "NEXT" while a forecast names it the next to burst. It follows the node's
## `pressure_changed` and `forecast_changed` signals and hides with the node under fog.
## Reads the simulation, never changes it.

const CALM_COLOR := Color(0.95, 0.78, 0.55)
const ALARM_COLOR := Color(1.0, 0.42, 0.12)
## Height above the vent, in metres.
const LIFT: float = 3.2

var _pressure: float = 0.0
var _burst: float = -1.0
var _next: bool = false


static func attach(vent: ResourceNode) -> VentGauge:
	var gauge: VentGauge = VentGauge.new()
	gauge.name = &"VentGauge"
	gauge.position = Vector3(0.0, LIFT, 0.0)
	gauge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gauge.no_depth_test = true
	gauge.fixed_size = true
	gauge.pixel_size = 0.0009
	gauge.font_size = 28
	gauge.outline_size = 8
	gauge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vent.add_child(gauge)
	vent.pressure_changed.connect(gauge.show_pressure)
	vent.forecast_changed.connect(gauge.show_forecast)
	gauge.show_pressure(vent.pressure, vent.seconds_to_burst)
	gauge.show_forecast(vent.is_next_to_erupt)
	return gauge


func show_pressure(pressure: float, seconds_to_burst: float) -> void:
	_pressure = pressure
	_burst = seconds_to_burst
	_refresh()


func show_forecast(next_to_erupt: bool) -> void:
	_next = next_to_erupt
	_refresh()


func _refresh() -> void:
	var line: String = "PRESSURE %d%%" % roundi(_pressure * 100.0)
	if _burst >= 0.0:
		var left: int = ceili(_burst)
		line = "ERUPTING %d:%02d" % [floori(left / 60.0), left % 60]
	if _next:
		line = "NEXT  ·  " + line
	text = line
	modulate = ALARM_COLOR if _burst >= 0.0 or _next else CALM_COLOR
