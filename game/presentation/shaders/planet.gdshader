shader_type spatial;
// A planet seen from orbit: banded surface from two colours, a terminator from
// the sun, and a thin bright atmosphere at the limb. Colours come from the
// StarBackdrop, one set per planet.

uniform vec3 surface_a : source_color = vec3(0.62, 0.36, 0.22);
uniform vec3 surface_b : source_color = vec3(0.86, 0.66, 0.46);
uniform vec3 atmosphere : source_color = vec3(1.0, 0.62, 0.36);
uniform float bands = 5.0;
uniform float swirl = 0.6;
uniform float spin = 0.004;

varying vec3 local_position;

float hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

float fbm(vec3 p) {
	return noise(p) * 0.5 + noise(p * 2.1) * 0.3 + noise(p * 4.3) * 0.2;
}

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec3 p = normalize(local_position);
	float angle = TIME * spin;
	p.xz = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * p.xz;
	float warp = fbm(p * 4.0) * swirl;
	float band = fbm(vec3(p.x * 2.0, p.y * bands * 2.0 + warp * 3.0, p.z * 2.0));
	float detail = fbm(p * 40.0);
	float fine = fbm(p * 110.0);
	float mixing = smoothstep(0.38, 0.62, band + (detail - 0.5) * 0.3 + (fine - 0.5) * 0.12);
	vec3 color = mix(surface_a, surface_b, mixing);
	color *= 0.75 + detail * 0.3 + fine * 0.2;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(color * 0.62, atmosphere, rim * 0.45);
	ROUGHNESS = 0.9;
	// The limb glows where the sun reaches it.
	EMISSION = atmosphere * rim * 0.35;
}
