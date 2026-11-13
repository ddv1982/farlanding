shader_type canvas_item;
// Full-screen dust haze for a Kessel storm: streaked noise blowing across the
// view. `intensity` 0..1 comes from StormVfx.

uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec3 dust_color : source_color = vec3(0.80, 0.56, 0.36);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 wind = vec2(0.42, 0.06);

void fragment() {
	// Stretched along the wind so the grain reads as streaks, in two speeds.
	vec2 uv = UV * vec2(1.4, 3.2);
	float near = texture(noise, uv + wind * TIME * 1.7).r;
	float far = texture(noise, uv * 0.45 + wind * TIME * 0.6 + vec2(0.3, 0.7)).r;
	float gust = 0.75 + 0.25 * sin(TIME * 0.7 + far * 6.0);
	float haze = mix(far, near * far * 1.6, 0.55) * gust;
	// Thicker toward the top of the screen, where the view is furthest away.
	float depth = mix(1.15, 0.7, UV.y);
	COLOR = vec4(dust_color * (0.85 + haze * 0.3), clamp((0.2 + haze * 0.55) * depth, 0.0, 1.0) * intensity * 0.5);
}
