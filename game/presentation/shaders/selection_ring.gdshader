shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
// Ground ring under a selected unit. Drawn on a flat quad; UV 0..1.

instance uniform vec3 ring_color : source_color = vec3(0.3, 0.9, 1.0);
uniform float thickness : hint_range(0.01, 0.3) = 0.07;
uniform float segments = 4.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ring = smoothstep(1.0 - thickness - 0.03, 1.0 - thickness, r) * smoothstep(1.0, 0.97, r);
	// Four gaps that rotate slowly, so the ring reads as "active" not static.
	float angle = atan(p.y, p.x) / TAU + TIME * 0.08;
	float gap = smoothstep(0.06, 0.10, abs(fract(angle * segments) - 0.5));
	float inner = smoothstep(1.0, 0.0, r) * 0.10 * step(r, 1.0 - thickness);
	ALBEDO = ring_color;
	ALPHA = clamp(ring * gap + inner, 0.0, 1.0);
}
