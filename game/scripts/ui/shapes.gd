class_name Shapes
extends Object
## Hình vẽ bằng code theo kiểu sprite Kenney: mảng màu phẳng có viền tối hơn màu nền.
## Viền khử răng cưa che mép đa giác (renderer Compatibility trên Web không có MSAA 2D).

const OUTLINE := 0.6
const OUTLINE_DARKEN := 0.5
const SEGMENTS := 18

static var _unit := _circle()


static func oval(c: CanvasItem, center: Vector2, rx: float, ry: float, color: Color, rot := 0.0, outlined := true) -> void:
	polygon(c, ellipse(center, rx, ry, rot), color, outlined)


static func polygon(c: CanvasItem, points: PackedVector2Array, color: Color, outlined := true) -> void:
	c.draw_colored_polygon(points, color)
	if outlined:
		var ring := points.duplicate()
		ring.append(points[0])
		c.draw_polyline(ring, color.darkened(OUTLINE_DARKEN), OUTLINE, true)


## Nét dày có viền: vẽ nét tối to hơn trước, rồi nét màu chồng lên.
static func stroke(c: CanvasItem, points: PackedVector2Array, color: Color, width: float) -> void:
	c.draw_polyline(points, color.darkened(OUTLINE_DARKEN), width + OUTLINE * 2.0, true)
	c.draw_polyline(points, color, width, true)


static func ellipse(center: Vector2, rx: float, ry: float, rot := 0.0) -> PackedVector2Array:
	return Transform2D(rot, Vector2(rx, ry), 0.0, center) * _unit


static func _circle() -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in SEGMENTS:
		points.append(Vector2.from_angle(TAU * i / SEGMENTS))
	return points
