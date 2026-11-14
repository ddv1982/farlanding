shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
// One-shot ground pulse where an order was given. `progress` runs 0 -> 1.

instance uniform vec3 marker_color : source_color = vec3(0.4, 1.0, 0.5);
instance uniform float progress : hint_range(0.0, 1.0) = 0.0;
// An attack order: a cross inside a broken ring, so it differs from a move in
// shape and not only in colour and size.
instance uniform bool attack = false;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	// Two rings collapsing inward onto the target point.
	float radius = mix(1.0, 0.18, progress);
	float outer = 1.0 - smoothstep(0.0, 0.08, abs(r - radius));
	float inner = 1.0 - smoothstep(0.0, 0.05, abs(r - radius * 0.55));
	float dot_core = 1.0 - smoothstep(0.05, 0.12, r);
	float shape = outer + inner * 0.6 + dot_core;
	if (attack) {
		// Four gaps in the ring and a diagonal cross through the target point.
		float angle = fract(atan(p.y, p.x) / TAU + 0.125);
		float gap = smoothstep(0.03, 0.06, abs(fract(angle * 4.0) - 0.5));
		float arm = min(abs(p.x - p.y), abs(p.x + p.y)) * 0.7071;
		float cross = (1.0 - smoothstep(0.03, 0.07, arm)) * step(r, radius * 0.5);
		shape = outer * gap + cross;
	}
	ALBEDO = marker_color;
	ALPHA = clamp(shape, 0.0, 1.0) * (1.0 - progress * progress);
}
