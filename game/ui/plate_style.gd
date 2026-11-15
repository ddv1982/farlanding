class_name PlateStyle
extends StyleBox
## The look of every panel and button: a plate of field equipment. A rectangle with
## its top-left and bottom-right corners cut at 45 degrees, a thin outline, and up to
## two small lights: a `marker` bar along the top edge (panels) and a `lamp` strip
## down the left edge (buttons). Drawn by hand because StyleBoxFlat can only round.

## Fill of the plate.
var fill: Color = Color.BLACK
## Outline, one pixel wide.
var line: Color = Color.WHITE
## Length of the two corner cuts, px.
var cut: float = 8.0
## Colour of the bar along the top edge; transparent draws none.
var marker: Color = Color.TRANSPARENT
## Length of that bar, px.
var marker_length: float = 36.0
## Colour of the strip down the left edge; transparent draws none.
var lamp: Color = Color.TRANSPARENT
## Soft shadow around the plate, px; 0 draws none.
var shadow: float = 0.0


func _init(p_fill: Color = Color.BLACK, p_line: Color = Color.WHITE, p_cut: float = 8.0) -> void:
	fill = p_fill
	line = p_line
	cut = p_cut


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var corner: float = minf(cut, minf(rect.size.x, rect.size.y) * 0.5)
	if shadow > 0.0:
		_draw_shadow(to_canvas_item, rect, corner)
	RenderingServer.canvas_item_add_polygon(
		to_canvas_item, outline(rect, corner), PackedColorArray([fill])
	)
	if line.a > 0.0:
		# Half a pixel in, so the one-pixel line sits on whole pixels.
		var edge: PackedVector2Array = outline(rect.grow(-0.5), corner)
		edge.append(edge[0])
		RenderingServer.canvas_item_add_polyline(
			to_canvas_item, edge, PackedColorArray([line]), 1.0, true
		)
	if marker.a > 0.0:
		var length: float = minf(marker_length, rect.size.x - corner * 2.0)
		RenderingServer.canvas_item_add_rect(
			to_canvas_item,
			Rect2(rect.position + Vector2(corner + 2.0, 0.0), Vector2(length, 2.0)),
			marker
		)
	if lamp.a > 0.0:
		var top: float = corner + 3.0
		RenderingServer.canvas_item_add_rect(
			to_canvas_item,
			Rect2(rect.position + Vector2(3.0, top), Vector2(2.0, rect.size.y - top - 4.0)),
			lamp
		)


## The plate's six corners for `rect`, clockwise from the top-left cut.
static func outline(rect: Rect2, corner: float) -> PackedVector2Array:
	var left: float = rect.position.x
	var top: float = rect.position.y
	var right: float = rect.end.x
	var bottom: float = rect.end.y
	return PackedVector2Array(
		[
			Vector2(left + corner, top),
			Vector2(right, top),
			Vector2(right, bottom - corner),
			Vector2(right - corner, bottom),
			Vector2(left, bottom),
			Vector2(left, top + corner),
		]
	)


func _draw_shadow(to_canvas_item: RID, rect: Rect2, corner: float) -> void:
	const STEPS: int = 6
	for step: int in STEPS:
		var grow: float = shadow * float(STEPS - step) / float(STEPS)
		RenderingServer.canvas_item_add_polygon(
			to_canvas_item,
			outline(rect.grow(grow), corner + grow * 0.5),
			PackedColorArray([Color(0, 0, 0, 0.09)])
		)
