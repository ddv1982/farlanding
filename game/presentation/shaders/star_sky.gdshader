shader_type sky;
// Deep space behind the campaign screens: a dense field of small stars in two
// sizes, a few bright ones, and a faint band of dust in the expedition's colours.

uniform vec3 space_color : source_color = vec3(0.006, 0.009, 0.016);
uniform vec3 band_color : source_color = vec3(0.10, 0.16, 0.24);
uniform vec3 band_warm : source_color = vec3(0.22, 0.10, 0.05);
uniform float star_density : hint_range(0.0, 1.0) = 0.5;

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

float stars(vec3 dir, float cells, float threshold) {
	vec3 p = dir * cells;
	vec3 cell = floor(p);
	float seed = hash(cell);
	if (seed < threshold) {
		return 0.0;
	}
	vec3 centre = cell + 0.5 + (vec3(hash(cell + 1.7), hash(cell + 4.1), hash(cell + 8.3)) - 0.5) * 0.6;
	float d = length(p - centre);
	float brightness = (seed - threshold) / (1.0 - threshold);
	return smoothstep(0.22, 0.0, d) * (0.35 + brightness);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	// A tilted band of dust across the sky.
	float lane = 1.0 - abs(dot(dir, normalize(vec3(0.35, 0.8, -0.45))));
	float cloud = noise(dir * 3.0) * 0.6 + noise(dir * 9.0) * 0.4;
	float band = pow(lane, 6.0) * cloud;
	vec3 color = space_color + mix(band_color, band_warm, noise(dir * 2.0 + 7.0)) * band * 0.55;
	float field = stars(dir, 90.0, 1.0 - 0.10 * star_density)
			+ stars(dir, 160.0, 1.0 - 0.14 * star_density) * 0.6
			+ stars(dir, 40.0, 1.0 - 0.02 * star_density) * 1.8;
	vec3 tint = mix(vec3(0.75, 0.86, 1.0), vec3(1.0, 0.86, 0.7), hash(floor(dir * 90.0) + 2.0));
	color += tint * field * (0.6 + band * 1.5);
	COLOR = color;
}
