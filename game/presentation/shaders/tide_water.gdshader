shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;
// The sea on a tidal map: one flat sheet that TideVfx raises and lowers. Shallow
// water is clear over the sand and deepens to a dark teal; a line of foam marks
// the shore, and the surface carries two sets of slow ripples.

#include "fog.gdshaderinc"

uniform vec3 shallow_color : source_color = vec3(0.34, 0.62, 0.60);
uniform vec3 deep_color : source_color = vec3(0.04, 0.20, 0.26);
uniform vec3 foam_color : source_color = vec3(0.92, 0.96, 0.94);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
// Metres of water at which the bottom is no longer seen.
uniform float clarity = 2.2;
uniform float foam_width = 0.28;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Depth of the water under this pixel, from the scene behind it.
	float scene_depth = texture(depth_texture, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	behind.xyz /= behind.w;
	float thickness = max(VERTEX.z - behind.z, 0.0);

	vec2 flow_a = world_pos.xz / 14.0 + vec2(TIME * 0.012, TIME * 0.007);
	vec2 flow_b = world_pos.xz / 5.0 - vec2(TIME * 0.02, -TIME * 0.011);
	float ripple = texture(noise_tex, flow_a).r * 0.6 + texture(noise_tex, flow_b).r * 0.4;

	float depth_mix = 1.0 - exp(-thickness / clarity);
	vec3 water = mix(shallow_color, deep_color, depth_mix);
	water *= 0.9 + ripple * 0.25;

	// Foam where the water is thinnest, broken up so it is not a ruled line.
	float foam = smoothstep(foam_width, 0.0, thickness - (ripple - 0.5) * 0.25);
	foam *= smoothstep(0.25, 0.6, texture(noise_tex, world_pos.xz / 2.2 + TIME * 0.03).r + 0.25);

	vec2 fog = fog_at(world_pos);
	ALBEDO = fog_color(mix(water, foam_color, foam * 0.85), fog);
	ALPHA = clamp(smoothstep(0.0, 0.12, thickness) * mix(0.55, 0.94, depth_mix) + foam * 0.5, 0.0, 1.0);
	ROUGHNESS = mix(0.08, 0.5, foam);
	SPECULAR = 0.6 * fog.r;
	NORMAL_MAP = vec3(0.5 + (texture(noise_tex, flow_b + 0.31).r - 0.5) * 0.5,
			0.5 + (texture(noise_tex, flow_a + 0.63).r - 0.5) * 0.5, 1.0);
	NORMAL_MAP_DEPTH = 0.6;
}
