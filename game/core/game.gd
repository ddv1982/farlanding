extends Node
## Scene flow (autoload `Game`). Stub: the project boots straight into MAIN_SCENE;
## menus, mission loading and the campaign layer hook in here later.

const MAIN_SCENE: String = "res://main.tscn"


## Switches to `path` at the end of the frame.
func goto_scene(path: String) -> void:
	get_tree().change_scene_to_file.call_deferred(path)


func goto_main() -> void:
	goto_scene(MAIN_SCENE)
