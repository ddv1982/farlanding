shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
// One-shot ground pulse where an order was given. `progress` runs 0 -> 1.

instance uniform vec3 marker_color : source_color = vec3(0.4, 1.0, 0.5);
instance uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	// Two rings collapsing inward onto the target point.
	float radius = mix(1.0, 0.18, progress);
	float outer = smoothstep(0.08, 0.0, abs(r - radius));
	float inner = smoothstep(0.05, 0.0, abs(r - radius * 0.55));
	float dot_core = smoothstep(0.12, 0.05, r);
	ALBEDO = marker_color;
	ALPHA = clamp(outer + inner * 0.6 + dot_core, 0.0, 1.0) * (1.0 - progress * progress);
}
