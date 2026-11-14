extends GutTest


func test_focus_loss_clears_camera_drag() -> void:
	var camera: RtsCamera = RtsCamera.new()
	add_child_autofree(camera)
	camera.set("_dragging", true)
	camera.set("_mouse_inside", true)
	camera.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var dragging: bool = camera.get("_dragging")
	assert_false(dragging)
	var inside: bool = camera.get("_mouse_inside")
	assert_true(inside)


func test_focus_loss_clears_selection_gestures() -> void:
	var controller: SelectionController = SelectionController.new()
	add_child_autofree(controller)
	controller.set("_pressing", true)
	controller.set("_box_dragging", true)
	controller.set("_shift_latched", true)
	controller.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var pressing: bool = controller.get("_pressing")
	var boxing: bool = controller.get("_box_dragging")
	var latched: bool = controller.get("_shift_latched")
	assert_false(pressing)
	assert_false(boxing)
	assert_false(latched)


func test_pointer_exit_cancels_an_unfinished_selection_drag() -> void:
	var controller: SelectionController = SelectionController.new()
	add_child_autofree(controller)
	controller.set("_pressing", true)
	controller.set("_box_dragging", true)
	controller.notification(NOTIFICATION_WM_MOUSE_EXIT)
	var pressing: bool = controller.get("_pressing")
	var dragging: bool = controller.get("_box_dragging")
	assert_false(pressing)
	assert_false(dragging)
