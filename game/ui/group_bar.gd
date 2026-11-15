class_name GroupBar
extends HBoxContainer
## The player's control groups on the HUD: one small badge per group that holds
## living units, in group order, reading "<group> · <units>" ("1 · 5"). Clicking a
## badge recalls the group like its key does (twice quickly centres the camera);
## right-clicking it puts the selection in that group instead (a way to replace a
## group that no browser takes, unlike Ctrl or, on Linux, Alt + a number). A
## badge lights up briefly when its group is stored or added to, disappears when its
## last unit dies, and the bar hides while no group exists.

## How long a badge stays lit after its group was stored or added to, in seconds.
const FLASH_SECONDS: float = 0.6

var _controller: SelectionController
var _groups: ControlGroups
## Group number -> its badge (all nine exist; empty groups are hidden).
var _badges: Dictionary[int, Button] = {}
## Group number -> seconds its badge stays lit.
var _flash_left: Dictionary[int, float] = {}


func _init() -> void:
	name = &"GroupBar"
	add_theme_constant_override(&"separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for group: int in range(1, ControlGroups.COUNT + 1):
		var group_badge: Button = HudStyle.make_small_button("")
		group_badge.name = StringName("Group%d" % group)
		group_badge.pressed.connect(_on_badge_pressed.bind(group))
		group_badge.gui_input.connect(_on_badge_input.bind(group))
		group_badge.visible = false
		add_child(group_badge)
		_badges[group] = group_badge
	visible = false


func _ready() -> void:
	Events.entity_died.connect(_on_entity_died)
	Settings.changed.connect(refresh)


## Shows the groups of `controller` and recalls them through it.
func setup(controller: SelectionController) -> void:
	_controller = controller
	_groups = controller.control_groups() if controller != null else null
	if _groups != null:
		_groups.changed.connect(refresh)
		_groups.stored.connect(_on_group_stored)
	refresh()


## Reads every group's living count again and shows the badges that have units.
func refresh() -> void:
	var any: bool = false
	for group: int in _badges:
		var group_badge: Button = _badges[group]
		var units: int = _groups.count(group) if _groups != null else 0
		group_badge.visible = units > 0
		any = any or units > 0
		group_badge.text = "%d · %d" % [group, units]
		var key: String = KeyBindings.label(StringName("control_group_%d" % group))
		group_badge.tooltip_text = (
			(
				"Group %d: %d units. Click (or %s) to select it, twice to centre on it.\n"
				+ "Right-click, Alt+%s or Ctrl+%s: the selection becomes this group.\n"
				+ "Shift+%s adds the selection to it."
			)
			% [group, units, key, key, key, key]
		)
	visible = any


## The badge of group `group` (1..9).
func badge(group: int) -> Button:
	return _badges.get(group, null)


## True while the badge of `group` is lit after a store or add.
func is_flashing(group: int) -> bool:
	return _flash_left.has(group)


func _process(delta: float) -> void:
	if _flash_left.is_empty():
		return
	for group: int in _flash_left.keys():
		var left: float = _flash_left[group] - delta
		if left > 0.0:
			_flash_left[group] = left
		else:
			_flash_left.erase(group)
			_light(group, false)


func _on_group_stored(group: int) -> void:
	_flash_left[group] = FLASH_SECONDS
	_light(group, true)


func _light(group: int, lit: bool) -> void:
	var lamp: Button = _badges.get(group, null)
	if lamp == null:
		return
	lamp.add_theme_stylebox_override(
		&"normal", HudStyle.button_style(&"pressed" if lit else &"normal")
	)
	lamp.add_theme_color_override(
		&"font_color", HudStyle.ACCENT_COLOR if lit else HudStyle.TEXT_COLOR
	)


func _on_badge_pressed(group: int) -> void:
	if _controller != null:
		_controller.recall_group(group)


## Right click on a badge: the selection replaces the group (nothing selected: no
## change, so a stray click cannot empty a group).
func _on_badge_input(event: InputEvent, group: int) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_RIGHT:
		return
	accept_event()
	if _controller != null and not _controller.selection.is_empty():
		_controller.store_group(group)


func _on_entity_died(entity: Node3D) -> void:
	if entity is Unit:
		refresh.call_deferred()
