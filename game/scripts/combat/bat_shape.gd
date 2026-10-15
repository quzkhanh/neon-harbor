class_name BatShape
extends Object
## Hình cây gậy bóng chày vẽ bằng code: thân thon dần về phía tay cầm, viền tối, băng quấn ở cán, vệt sáng dọc thân.
## Dùng cho gậy cầm trên tay (HeldBat) và gậy trong cú vung (SwingArc) để hai nơi trông giống nhau.

const LENGTH := 58.0
const HEAD_WIDTH := 14.0
const GRIP_WIDTH := 5.0
const GRIP_PART := 0.28  # phần chiều dài ở cán, quấn băng
const OUTLINE := 1.6


## Vẽ gậy lên `canvas`: cán ở `from`, đầu gậy chĩa theo `angle`; `length` co giãn theo tầm đánh.
static func draw(canvas: CanvasItem, from: Vector2, angle: float, length := LENGTH, alpha := 1.0) -> void:
	var dir := Vector2.from_angle(angle)
	var side := dir.orthogonal()
	var grip_end := from + dir * length * GRIP_PART
	var tip := from + dir * length
	var shape := PackedVector2Array([
		from + side * GRIP_WIDTH * 0.4, grip_end + side * GRIP_WIDTH * 0.5, tip + side * HEAD_WIDTH * 0.45,
		tip - side * HEAD_WIDTH * 0.45, grip_end - side * GRIP_WIDTH * 0.5, from - side * GRIP_WIDTH * 0.4])
	canvas.draw_colored_polygon(_outline(shape, from + dir * length * 0.5), Color(Palette.BAT_OUTLINE, alpha))
	canvas.draw_colored_polygon(shape, Color(Palette.BAT_WOOD, alpha))
	canvas.draw_line(from, grip_end, Color(Palette.BAT_GRIP, alpha), GRIP_WIDTH, true)
	canvas.draw_line(grip_end + side * -1.5, tip - dir * 2.0 - side * 1.5, Color(Palette.BAT_HIGHLIGHT, alpha * 0.7), 1.5, true)


## Đa giác phình ra khỏi tâm một đoạn OUTLINE: làm viền.
static func _outline(shape: PackedVector2Array, center: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in shape:
		out.append(p + (p - center).normalized() * OUTLINE)
	return out
