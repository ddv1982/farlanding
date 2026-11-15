extends GutTest
## The variable font must select real body/button/heading weights, not its Thin default.


func test_saira_roles_keep_normal_width_and_readable_weights() -> void:
	var roles: Dictionary = {
		HudStyle.FONT_BODY: 400.0, HudStyle.FONT_BUTTON: 500.0, HudStyle.FONT_HEADING: 600.0
	}
	for path: String in roles:
		var font: FontVariation = HudStyle.font(path) as FontVariation
		assert_not_null(font, path)
		var weight: float = font.variation_opentype[2003265652]
		var expected: float = roles[path]
		assert_eq(weight, expected)
		var width: float = font.variation_opentype[2003072104]
		assert_eq(width, 100.0)
		for character: String in ["A", "a", "0", "1", "·", "…", "—"]:
			assert_true(font.has_char(character.unicode_at(0)), character)


func test_credits_include_the_bundled_saira_license() -> void:
	var license_text: String = FileAccess.get_file_as_string("res://assets/fonts/OFL.txt")
	assert_true(license_text.contains("Saira Project Authors"))
	assert_true(license_text.contains("SIL OPEN FONT LICENSE Version 1.1"))
