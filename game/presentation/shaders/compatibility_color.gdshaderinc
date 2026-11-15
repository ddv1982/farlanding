// Compatibility has an LDR target. Preserve the hue of overbright highlights
// instead of letting each channel clip independently to white or yellow.
vec3 display_emission(vec3 color) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return color / max(1.0, max(color.r, max(color.g, color.b)));
#else
	return color;
#endif
}
