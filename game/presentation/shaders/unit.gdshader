shader_type spatial;
// Shared surface for every unit and building. Models carry no textures of
// their own: each face's UV points at one swatch of the palette atlas written
// by art/pipeline/fl.py.

uniform sampler2D palette_albedo : source_color, filter_nearest, repeat_disable;
// r = roughness, g = metallic, b = emission / 8, a = team-colour mask
uniform sampler2D palette_surface : hint_default_black, filter_nearest, repeat_disable;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.25;
// Planet dust that collects on the lower hull, and how high it reaches (metres).
uniform vec3 dust_color : source_color = vec3(0.62, 0.42, 0.27);
uniform float dust_height = 1.1;
uniform float dust_amount : hint_range(0.0, 1.0) = 0.45;

instance uniform vec3 team_color : source_color = vec3(0.1, 0.45, 1.0);
// 0 = pristine, 1 = wrecked: darkens and desaturates the surface.
instance uniform float damage : hint_range(0.0, 1.0) = 0.0;
// Construction: the model is revealed from the ground up to
// build_progress * build_height metres, with a glowing band at the build front.
instance uniform float build_progress : hint_range(0.0, 1.0) = 1.0;
instance uniform float build_height = 10.0;
uniform vec3 build_glow : source_color = vec3(0.25, 0.95, 1.0);

#include "fog.gdshaderinc"

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = texture(palette_albedo, UV).rgb;
	vec4 surface = texture(palette_surface, UV);
	base = mix(base, team_color, surface.a);
	// COLOR.r carries height above the model origin (metres / 8). Models without
	// it read as white, i.e. "high", and are left untouched.
	float height = COLOR.r * 8.0;
	float build_front = build_progress * (build_height + 0.3);
	if (build_progress < 1.0 && height > build_front) {
		discard;
	}
	float lit = step(surface.b, 0.001);
	base = mix(base, dust_color, (1.0 - smoothstep(0.0, dust_height, height)) * dust_amount * lit);
	base *= mix(0.72, 1.0, smoothstep(0.0, 0.9, height));
	float grey = dot(base, vec3(0.299, 0.587, 0.114));
	base = mix(base, vec3(grey) * 0.45, damage * 0.7);

	vec2 fog = fog_at(world_pos);
	ALBEDO = fog_color(base, fog);
	ROUGHNESS = mix(surface.r, 0.95, damage * 0.6);
	METALLIC = surface.g;
	EMISSION = base * surface.b * 8.0 * (1.0 - damage);
	// Soft rim so silhouettes read against terrain from RTS height.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION += base * rim * rim_strength;
	// Lights and rim belong to what is seen now, not to a remembered building.
	EMISSION *= fog.r;
	if (build_progress < 1.0) {
		EMISSION += build_glow * (1.0 - smoothstep(0.0, 0.35, build_front - height)) * 3.0;
	}
}
