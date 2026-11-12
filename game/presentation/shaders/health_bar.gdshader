shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled;
// Camera-facing health bar above a unit or building. Quad UV 0..1.

instance uniform float health : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	// Billboard: keep the node's position, take the camera's orientation.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 border = step(vec2(0.03, 0.18), UV) * step(UV, vec2(0.97, 0.82));
	float inside = border.x * border.y;
	vec3 fill = mix(vec3(0.95, 0.18, 0.10), vec3(0.98, 0.78, 0.12), smoothstep(0.15, 0.5, health));
	fill = mix(fill, vec3(0.30, 0.90, 0.35), smoothstep(0.5, 0.8, health));
	float filled = step(UV.x, 0.03 + 0.94 * health);
	ALBEDO = mix(vec3(0.02), mix(vec3(0.10), fill, filled), inside);
	ALPHA = 0.9;
}
