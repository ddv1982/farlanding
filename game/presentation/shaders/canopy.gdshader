shader_type spatial;
render_mode cull_disabled;
// Verdance tree crowns. Drawn as a screen-door (dithered) layer so the player still
// sees their own units under it, while its shadow dapples the ground. `opacity` is
// how much of the crown is drawn.

uniform vec3 leaf_color : source_color = vec3(0.07, 0.25, 0.10);
uniform vec3 leaf_color_alt : source_color = vec3(0.22, 0.36, 0.08);
uniform vec3 under_color : source_color = vec3(0.02, 0.07, 0.05);
uniform float opacity : hint_range(0.0, 1.0) = 0.62;
uniform float sway = 0.18;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

#include "fog.gdshaderinc"

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world_pos.x * 0.21 + world_pos.z * 0.17;
	VERTEX.x += sin(TIME * 0.7 + phase) * sway;
	VERTEX.y += sin(TIME * 0.9 + phase * 1.3) * sway * 0.5;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float dither(vec2 pixel) {
	return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	float broad = texture(noise_tex, world_pos.xz / 38.0).r;
	float fine = texture(noise_tex, world_pos.xz / 4.0 + 0.4).r;
	// Thinner at each pad's edge, so crowns read as leaves, not as solid lids.
	float facing = abs(world_normal.y);
	float cover = opacity * mix(0.55, 1.0, smoothstep(0.15, 0.8, facing)) * (0.8 + 0.4 * fine);
	if (dither(FRAGCOORD.xy) > cover) {
		discard;
	}
	vec3 leaf = mix(leaf_color, leaf_color_alt, smoothstep(0.3, 0.7, broad * 0.6 + fine * 0.4));
	leaf = mix(under_color, leaf, smoothstep(-0.3, 0.9, world_normal.y));
	leaf *= 0.75 + 0.5 * smoothstep(9.5, 13.0, world_pos.y);
	ALBEDO = fog_color(leaf, fog_at(world_pos));
	ROUGHNESS = 0.8;
	BACKLIGHT = leaf_color_alt * 0.25;
}
