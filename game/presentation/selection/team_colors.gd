class_name TeamColors
extends RefCounted
## The one source of team colour: per faction, in the palette the player chose
## (`Settings.colour_palette`). Unit and building visuals (the unit shader's
## `team_color`) and their selection rings, the engines' owner tint, rally markers,
## the minimap, order markers and the shots of each side all ask here.
##
## Besides the default (blue against red) there are two palettes for colour
## blindness that differ in brightness as well as hue: blue against orange for
## red-green blindness (deuteranopia, protanopia) and teal against magenta for
## blue-yellow blindness (tritanopia); the Custodians are near-white in both.

## Palette id -> [player, hostile, Custodians].
const PALETTES: Dictionary[StringName, Array] = {
	&"default":
	[
		Color(0.25, 0.55, 1.0),  # 0: player (Concord expedition)
		Color(0.9, 0.18, 0.12),  # 1: hostile (Halcyon Combine): enemies read red
		Color(0.85, 0.75, 0.45),  # 2: Custodians
	],
	&"red_green": [Color(0.15, 0.4, 1.0), Color(1.0, 0.62, 0.05), Color(0.93, 0.93, 0.93)],
	&"blue_yellow": [Color(0.0, 0.72, 0.78), Color(0.85, 0.1, 0.4), Color(0.95, 0.95, 0.95)],
}
## Palette id -> [player's shots, other factions' shots] (bright: they glow).
const SHOTS: Dictionary[StringName, Array] = {
	&"default": [Color(0.35, 0.92, 1.0), Color(0.25, 1.0, 0.55)],
	&"red_green": [Color(0.45, 0.7, 1.0), Color(1.0, 0.75, 0.25)],
	&"blue_yellow": [Color(0.3, 0.95, 0.95), Color(1.0, 0.35, 0.55)],
}
## Palette id -> [move order marker, attack order marker].
const MARKERS: Dictionary[StringName, Array] = {
	&"default": [Color(0.45, 1.0, 0.55), Color(1.0, 0.4, 0.3)],
	&"red_green": [Color(0.45, 0.72, 1.0), Color(1.0, 0.62, 0.05)],
	&"blue_yellow": [Color(0.2, 0.9, 0.9), Color(1.0, 0.25, 0.5)],
}
## Labels for the settings.
const LABELS: Dictionary[StringName, String] = {
	&"default": "Default  (blue / red)",
	&"red_green": "Red-green safe  (blue / orange)",
	&"blue_yellow": "Blue-yellow safe  (teal / magenta)",
}
## The player's faction in every mission so far (the shots of anyone else use the
## other colour).
const PLAYER: int = 0
const HOSTILE: int = 1


## Team colour of `faction` in the chosen palette (white for an unknown faction).
static func for_faction(faction: int) -> Color:
	var colors: Array = PALETTES[palette()]
	if faction >= 0 and faction < colors.size():
		return colors[faction]
	return Color.WHITE


## The palette in use (Settings.colour_palette, or the default if unknown).
static func palette() -> StringName:
	var chosen: StringName = Settings.colour_palette
	return chosen if PALETTES.has(chosen) else &"default"


## Colour of the shots and muzzle flashes of `faction`.
static func shot_color(faction: int) -> Color:
	var colors: Array = SHOTS[palette()]
	return colors[0] if faction == PLAYER else colors[1]


## Colour of the marker a move (or attack) order leaves on the ground.
static func order_marker(attack: bool) -> Color:
	var colors: Array = MARKERS[palette()]
	return colors[1] if attack else colors[0]


## Relative luminance (WCAG) of `color`, for checking that palettes differ in
## brightness and not only in hue.
static func luminance(color: Color) -> float:
	var linear: Color = color.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b
