shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
// Ground sweep under a site being scanned. Quad UV 0..1; progress 0..1 fills
// an arc round the rim while pulses travel outward.

instance uniform vec3 ring_color : source_color = vec3(0.35, 0.92, 1.0);
instance uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = fract(atan(p.x, -p.y) / TAU + 1.0);
	float rim = smoothstep(0.86, 0.90, r) * (1.0 - smoothstep(0.96, 1.0, r));
	float filled = step(angle, progress);
	float pulse = fract(r * 1.5 - TIME * 0.6);
	float waves = (1.0 - smoothstep(0.0, 0.12, pulse)) * (1.0 - smoothstep(0.7, 0.9, r)) * 0.35;
	float sweep = (1.0 - smoothstep(0.0, 0.05, abs(angle - fract(TIME * 0.35)))) * step(r, 0.9) * 0.5;
	ALBEDO = ring_color;
	ALPHA = clamp(rim * mix(0.25, 1.0, filled) + waves + sweep, 0.0, 1.0);
}
