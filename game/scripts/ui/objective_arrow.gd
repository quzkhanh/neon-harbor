class_name ObjectiveArrow
extends Control
## Mũi tên ở mép màn hình chỉ hướng tới mục tiêu khi mục tiêu nằm ngoài khung hình.

const MARGIN := 46.0
const LENGTH := 26.0
const HALF_WIDTH := 15.0
const OUTLINE_WIDTH := 3.0

var city: City


func _init(c: City) -> void:
	city = c
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var target := city.missions.target()
	if target == null or not city.player.alive:
		return
	var screen := city.get_viewport().get_canvas_transform() * target.global_position
	var area := Rect2(Vector2.ZERO, size).grow(-MARGIN)
	if area.has_point(screen):
		return
	var center := size * 0.5
	var dir := (screen - center).normalized()
	var scale_to_edge := minf(absf(area.size.x * 0.5 / dir.x) if dir.x != 0.0 else INF, absf(area.size.y * 0.5 / dir.y) if dir.y != 0.0 else INF)
	var tip := center + dir * scale_to_edge
	var side := dir.orthogonal() * HALF_WIDTH
	var pts := PackedVector2Array([tip, tip - dir * LENGTH + side, tip - dir * LENGTH - side])
	draw_colored_polygon(pts, target.color)
	draw_polyline(pts + PackedVector2Array([tip]), Palette.OUTLINE, OUTLINE_WIDTH, true)
