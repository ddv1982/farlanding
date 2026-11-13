shader_type spatial;
render_mode unshaded, cull_back;
// A lava river: one flat sheet under the terrain's river beds. A dark crust
// drifts slowly on a bright flow; cracks open and close as two noise fields
// slide past each other.

#include "fog.gdshaderinc"

uniform vec3 hot_color : source_color = vec3(1.0, 0.62, 0.12);
uniform vec3 flow_color : source_color = vec3(0.95, 0.22, 0.03);
uniform vec3 crust_color : source_color = vec3(0.06, 0.035, 0.03);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float glow = 2.6;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 drift = vec2(TIME * 0.006, TIME * 0.004);
	float plates = texture(noise_tex, world_pos.xz / 11.0 + drift).r;
	float seams = texture(noise_tex, world_pos.xz / 4.5 - drift * 1.7 + 0.4).r;
	float pulse = 0.85 + 0.15 * sin(TIME * 0.6 + plates * 9.0);
	// Crust where the two fields agree; bright seams where they part.
	float crack = 1.0 - smoothstep(0.02, 0.16, abs(plates - seams));
	float molten = clamp(crack + smoothstep(0.62, 0.8, plates) * 0.6, 0.0, 1.0);
	vec3 lava = mix(flow_color, hot_color, crack) * glow * pulse;
	vec3 color = mix(crust_color, lava, molten);
	vec2 fog = fog_at(world_pos);
	// Unexplored lava is charted dark like everything else; remembered lava dims.
	ALBEDO = fog_color(color, fog) * mix(3.0, 1.0, fog.r);
}
