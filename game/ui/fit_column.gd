class_name FitColumn
extends Container
## A column of controls, like a VBoxContainer, that never grows taller than the
## screen. Its scroll areas (made with `add_scroll`) give up height first, so what
## stands above and below them (a heading, the Back button) always stays in view.
## While everything fits, a scroll area is as tall as its content (or its fixed
## height) and nothing scrolls. Used by the menus that list a variable amount
## (missions, briefing, settings pages), at any window height and interface size.

## A scroll area shrinks no further than this, px (when the screen is that short).
const MIN_SCROLL_HEIGHT: float = 48.0

## Space between children, px.
var separation: int = 10:
	set(value):
		separation = value
		update_minimum_size()
		queue_sort()
## Height the screen keeps around the column (its margins, a panel's borders), px:
## the column is at most the viewport's height less this.
var outer_margin: float = 0.0:
	set(value):
		outer_margin = value
		update_minimum_size()

## Each scroll area made here -> its content.
var _contents: Dictionary[ScrollContainer, Control] = {}
## Each scroll area -> its fixed height while it fits, or -1 to follow its content.
var _heights: Dictionary[ScrollContainer, float] = {}


func _init(p_separation: int = 10) -> void:
	separation = p_separation
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Adds a scroll area (vertical only) holding `content`, at the end of the column.
## While the screen is tall enough it is `height` px tall, or as tall as `content`
## when `height` is negative; on a shorter screen it gives up height and scrolls.
func add_scroll(content: Control, height: float = -1.0) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.add_child(content)
	_contents[scroll] = content
	_heights[scroll] = height
	content.minimum_size_changed.connect(_refit)
	add_child(scroll)
	return scroll


## True when the scroll area `scroll` is shorter than its content (it scrolls).
func is_scrolling(scroll: ScrollContainer) -> bool:
	if not _contents.has(scroll):
		return false
	return scroll.size.y + 0.5 < _contents[scroll].get_combined_minimum_size().y


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			get_viewport().size_changed.connect(_refit)
		NOTIFICATION_EXIT_TREE:
			if get_viewport().size_changed.is_connected(_refit):
				get_viewport().size_changed.disconnect(_refit)
		NOTIFICATION_SORT_CHILDREN:
			_sort()


func _get_minimum_size() -> Vector2:
	var width: float = 0.0
	var natural: float = 0.0
	var smallest: float = 0.0
	var shown: Array[Control] = _shown()
	for child: Control in shown:
		width = maxf(width, child.get_combined_minimum_size().x)
		var height: float = _natural_height(child)
		natural += height
		smallest += _smallest_height(child, height)
	var gaps: float = float(separation * maxi(shown.size() - 1, 0))
	natural += gaps
	smallest += gaps
	if not is_inside_tree():
		return Vector2(width, natural)
	var limit: float = get_viewport_rect().size.y - outer_margin
	return Vector2(width, minf(natural, maxf(limit, smallest)))


func _sort() -> void:
	var shown: Array[Control] = _shown()
	var heights: Array[float] = []
	var total: float = float(separation * maxi(shown.size() - 1, 0))
	var give: float = 0.0
	for child: Control in shown:
		var height: float = _natural_height(child)
		heights.append(height)
		total += height
		give += height - _smallest_height(child, height)
	# Too tall: the scroll areas give up height, each in proportion to what it can.
	var excess: float = maxf(total - size.y, 0.0)
	var share: float = minf(excess / give, 1.0) if give > 0.0 else 0.0
	var y: float = 0.0
	for i: int in shown.size():
		var child: Control = shown[i]
		var height: float = heights[i]
		if _is_scroll(child):
			height -= (height - _smallest_height(child, height)) * share
		fit_child_in_rect(child, Rect2(0.0, y, size.x, height))
		y += height + float(separation)


func _shown() -> Array[Control]:
	var shown: Array[Control] = []
	for node: Node in get_children():
		var child: Control = node as Control
		if child != null and child.visible and not child.top_level:
			shown.append(child)
	return shown


func _is_scroll(child: Control) -> bool:
	var scroll: ScrollContainer = child as ScrollContainer
	return scroll != null and _contents.has(scroll)


func _natural_height(child: Control) -> float:
	var own: float = child.get_combined_minimum_size().y
	if not _is_scroll(child):
		return own
	var scroll: ScrollContainer = child as ScrollContainer
	var fixed: float = _heights[scroll]
	if fixed >= 0.0:
		return maxf(own, fixed)
	return maxf(own, _contents[scroll].get_combined_minimum_size().y)


func _smallest_height(child: Control, natural: float) -> float:
	if not _is_scroll(child):
		return natural
	return minf(natural, maxf(child.get_combined_minimum_size().y, MIN_SCROLL_HEIGHT))


func _refit() -> void:
	update_minimum_size()
	queue_sort()
