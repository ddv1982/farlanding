extends Node
## Autoload: gives every control, in the game and in the tests, the game's typeface
## and stock-control look (HudTheme) before any screen is built. It merges into the
## engine's default theme, not the root window's: a control under a CanvasLayer or
## other plain node does not inherit the window's theme, and most screens sit under
## one.


func _enter_tree() -> void:
	var look: Theme = HudTheme.build()
	var base: Theme = ThemeDB.get_default_theme()
	base.merge_with(look)
	base.default_font = look.default_font
	ThemeDB.fallback_font = look.default_font
