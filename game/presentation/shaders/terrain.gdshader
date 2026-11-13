shader_type spatial;
// Planet terrain. No painted textures: colour comes from slope, height and
// world-space noise, so any heightfield from art/terrain/ is shaded for free.

uniform vec3 ground_color : source_color = vec3(0.74, 0.53, 0.35);
uniform vec3 ground_color_alt : source_color = vec3(0.65, 0.43, 0.27);
uniform vec3 pale_color : source_color = vec3(0.88, 0.71, 0.50);
uniform vec3 rock_color : source_color = vec3(0.46, 0.25, 0.17);
uniform vec3 rock_color_alt : source_color = vec3(0.66, 0.40, 0.26);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float cliff_start : hint_range(0.0, 1.0) = 0.16;
uniform float cliff_end : hint_range(0.0, 1.0) = 0.38;
uniform float strata_scale = 1.1;
// Ground below this height is wet (tidal maps move it with the sea; the default
// keeps every other map dry).
uniform float wet_level = -1000.0;
uniform vec3 wet_tint : source_color = vec3(0.55, 0.62, 0.62);
// Ground below this height glows (lava maps: the banks of a lava river). The
// default keeps every other map dark.
uniform float heat_level = -1000.0;
uniform vec3 heat_color : source_color = vec3(1.0, 0.32, 0.05);

#include "fog.gdshaderinc"

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float broad = texture(noise_tex, world_pos.xz / 90.0).r;
	float mid = texture(noise_tex, world_pos.xz / 23.0 + 0.37).r;
	float fine = texture(noise_tex, world_pos.xz / 5.0 + 0.71).r;

	// Flat ground: two dust tones drifting across the basin, paler on high ground.
	vec3 ground = mix(ground_color_alt, ground_color, smoothstep(0.2, 0.8, broad * 0.6 + mid * 0.4));
	ground = mix(ground, pale_color, smoothstep(2.0, 4.0, world_pos.y) * 0.75);
	ground *= 0.90 + 0.20 * fine;

	// Cliffs: horizontal strata, wobbling slightly so bands are not ruler-straight.
	float band = world_pos.y * strata_scale + broad * 1.5 + mid * 0.35;
	float strata = smoothstep(0.35, 0.65, fract(band));
	vec3 rock = mix(rock_color, rock_color_alt, strata);
	rock *= 0.82 + 0.36 * fine;

	float slope = 1.0 - world_normal.y;
	float cliff = smoothstep(cliff_start, cliff_end, slope + (fine - 0.5) * 0.08);

	// Wet ground: darker, cooler and shinier, drying out over half a metre.
	float wet = smoothstep(wet_level + 0.5, wet_level - 0.1, world_pos.y + (mid - 0.5) * 0.3);
	vec3 surface = mix(ground, rock, cliff);
	surface = mix(surface, surface * wet_tint, wet);

	ALBEDO = fog_color(surface, fog_at(world_pos));
	ROUGHNESS = mix(mix(0.95, 0.85, cliff), 0.35, wet * 0.8);
	// Heat: strongest at the lava's surface, gone a metre and a half above it,
	// broken into cracks by the fine noise.
	float heat = smoothstep(heat_level + 1.5, heat_level, world_pos.y);
	heat *= heat * (0.35 + 0.65 * smoothstep(0.45, 0.7, fine));
	EMISSION = heat_color * heat * 2.5 * fog_at(world_pos).r;
	NORMAL_MAP = texture(detail_normal, world_pos.xz / 7.0).rgb;
	NORMAL_MAP_DEPTH = mix(0.55, 0.15, cliff);
}
