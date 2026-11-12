shader_type spatial;
// Shared surface for every unit and building. Models carry no textures of
// their own: each face's UV points at one swatch of the palette atlas written
// by art/pipeline/fl.py.

uniform sampler2D palette_albedo : source_color, filter_nearest, repeat_disable;
// r = roughness, g = metallic, b = emission / 8, a = team-colour mask
uniform sampler2D palette_surface : hint_default_black, filter_nearest, repeat_disable;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.25;

instance uniform vec3 team_color : source_color = vec3(0.1, 0.45, 1.0);
// 0 = pristine, 1 = wrecked: darkens and desaturates the surface.
instance uniform float damage : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 base = texture(palette_albedo, UV).rgb;
	vec4 surface = texture(palette_surface, UV);
	base = mix(base, team_color, surface.a);
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
