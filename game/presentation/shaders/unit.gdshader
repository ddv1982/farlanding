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

void fragment() {
	vec3 base = texture(palette_albedo, UV).rgb;
	vec4 surface = texture(palette_surface, UV);
	base = mix(base, team_color, surface.a);
	// COLOR.r carries height above the model origin (metres / 8). Models without
	// it read as white, i.e. "high", and are left untouched.
	float height = COLOR.r * 8.0;
	float lit = step(surface.b, 0.001);
	base = mix(base, dust_color, (1.0 - smoothstep(0.0, dust_height, height)) * dust_amount * lit);
	base *= mix(0.72, 1.0, smoothstep(0.0, 0.9, height));
	float grey = dot(base, vec3(0.299, 0.587, 0.114));
	base = mix(base, vec3(grey) * 0.45, damage * 0.7);

	ALBEDO = base;
	ROUGHNESS = mix(surface.r, 0.95, damage * 0.6);
	METALLIC = surface.g;
	EMISSION = base * surface.b * 8.0 * (1.0 - damage);
	// Soft rim so silhouettes read against terrain from RTS height.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION += base * rim * rim_strength;
}
