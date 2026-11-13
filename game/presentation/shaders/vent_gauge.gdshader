shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
// Pressure ring on the ground round an erupting vent. Quad UV 0..1. The rim fills
// clockwise with `pressure` (0..1) in twelve segments; `alarm` 0..1 turns it from
// amber to red and makes it beat.

instance uniform float pressure : hint_range(0.0, 1.0) = 0.0;
instance uniform float alarm : hint_range(0.0, 1.0) = 0.0;
uniform vec3 calm_color : source_color = vec3(1.0, 0.72, 0.36);
uniform vec3 alarm_color : source_color = vec3(1.0, 0.25, 0.08);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = fract(atan(p.x, -p.y) / TAU + 1.0);
	float rim = smoothstep(0.80, 0.83, r) * (1.0 - smoothstep(0.95, 0.98, r));
	// Twelve segments with gaps between them.
	float cell = fract(angle * 12.0);
	float segment = smoothstep(0.0, 0.06, cell) * (1.0 - smoothstep(0.86, 0.92, cell));
	float filled = step(angle, pressure);
	float beat = mix(1.0, 0.55 + 0.45 * sin(TIME * 9.0), alarm);
	ALBEDO = mix(calm_color, alarm_color, alarm);
	ALPHA = clamp(rim * segment * mix(0.14, 1.0, filled) * beat, 0.0, 1.0);
}
