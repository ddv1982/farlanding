shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled, blend_mix;
// Translucent preview of a building being placed: cyan when the spot is valid,
// red when it is not.

instance uniform vec3 ghost_color : source_color = vec3(0.25, 0.95, 1.0);

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float lines = 0.75 + 0.25 * step(0.5, fract(FRAGCOORD.y * 0.25));
	ALBEDO = ghost_color * (0.6 + rim);
	ALPHA = (0.32 + 0.5 * rim) * lines;
}
