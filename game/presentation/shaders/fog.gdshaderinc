// Fog of war, shared by every world shader.
//
// The simulation uploads one texture covering the map (see the vision system):
//   r = visible right now (0..1), g = explored at some point (0..1).
// fog_size is the map's side in metres; 0 means "no fog" (menus, showcases).

global uniform sampler2D fog_map : filter_linear, repeat_disable, hint_default_white;
global uniform float fog_origin_x;
global uniform float fog_origin_z;
global uniform float fog_size;

vec2 fog_at(vec3 world) {
	if (fog_size <= 0.0) {
		return vec2(1.0);
	}
	vec2 uv = (world.xz - vec2(fog_origin_x, fog_origin_z)) / fog_size;
	return texture(fog_map, uv).rg;
}

// Three looks: never seen = the orbital chart (dark, cold, colourless);
// seen before = a dimmed memory; visible = untouched.
vec3 fog_color(vec3 color, vec2 fog) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// Forward+ mixes in linear space; Compatibility shades in sRGB. Match the
	// chart/memory contrast without changing the vision texture or visibility.
	color = pow(max(color, vec3(0.0)), vec3(2.2));
#endif
	float grey = dot(color, vec3(0.299, 0.587, 0.114));
	// Values are low because they are still lit by the sun afterwards.
	vec3 charted = vec3(grey) * vec3(0.045, 0.062, 0.090);
	vec3 remembered = mix(vec3(grey), color, 0.5) * 0.30;
	vec3 result = mix(mix(charted, remembered, fog.g), color, fog.r);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	result = pow(max(result, vec3(0.0)), vec3(1.0 / 2.2));
#endif
	return result;
}
