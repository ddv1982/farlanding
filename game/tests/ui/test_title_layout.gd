extends GutTest
## The normal title menu fits without scrolling, including Continue and native Quit.

var _saved_size: Vector2i
var _saved_factor: float


func before_each() -> void:
	_saved_size = get_tree().root.size
	_saved_factor = get_tree().root.content_scale_factor


func after_each() -> void:
	get_tree().root.size = _saved_size
	get_tree().root.content_scale_factor = _saved_factor


func test_supported_title_sizes_fit_every_action_without_a_scrollbar() -> void:
	for ui_factor: float in [1.0, 1.3]:
		for can_continue: bool in [false, true]:
			get_tree().root.size = Vector2i(1152, 648)
			get_tree().root.content_scale_factor = ui_factor
			var screen: TitleScreen = TitleScreen.new()
			add_child(screen)
			screen.open(can_continue)
			await wait_physics_frames(3)
			assert_false(screen._menu_scroll.get_v_scroll_bar().visible, str(ui_factor))
			var view: Rect2 = screen.get_viewport_rect().grow(1.0)
			for node: Node in screen.find_children("*", "Button", true, false):
				var button: Button = node as Button
				if button.is_visible_in_tree():
					assert_true(view.encloses(button.get_global_rect()), button.text)
			screen.free()
			await wait_physics_frames(1)
