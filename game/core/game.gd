extends Node
## Autoload entry point for whole-scene navigation. Main owns the menu, campaign
## and landing transitions within MAIN_SCENE.

const MAIN_SCENE: String = "res://main.tscn"


## Switches to `path` at the end of the frame.
func goto_scene(path: String) -> void:
	get_tree().change_scene_to_file.call_deferred(path)


func goto_main() -> void:
	goto_scene(MAIN_SCENE)
