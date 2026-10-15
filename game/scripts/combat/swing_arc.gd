class_name SwingArc
extends Node2D
## Vệt chém của một cú cận chiến: cung sáng quét theo hướng vung rồi tắt dần. Tay không: trắng, ngắn; gậy: cam, dài,
## kèm hình cây gậy xoay theo cú vung. Cú đánh chẵn trong combo vung ngược chiều; cú cuối rộng và dày hơn.

const LIFE := 0.16
const SWEEP_PART := 0.55  # phần đời dành cho cú quét, phần còn lại là vệt mờ đi
const START := 0.5  # vệt hiện ra đã quét nửa chừng: lúc khựng hình (ngay khi trúng) thấy được cung và cây gậy chĩa vào mục tiêu
const INNER := 0.45  # bán kính trong của vệt, so với tầm đánh
const WIDTH := 7.0
const POINTS := 14
const BAT_WIDTH := 6.0

var _angle := 0.0
var _spread := 0.0
var _reach := 0.0
var _dir := 1.0
var _width := WIDTH
var _color := Palette.SWING_FISTS
var _bat := false
var _time := LIFE * SWEEP_PART * START


static func spawn(shooter: Node2D, w: Dictionary, angle: float, step: int) -> void:
	var a := SwingArc.new()
	a._bat = w.pose == "hold"
	a._color = Palette.SWING_BAT if a._bat else Palette.SWING_FISTS
	a._angle = angle
	a._spread = deg_to_rad(float(w.spread)) * (1.25 if step == Melee.COMBO_HITS else 1.0)
	a._reach = float(w.range) + Tuning.HUMAN_RADIUS
	a._dir = -1.0 if step % 2 == 0 else 1.0
	a._width = WIDTH * (1.5 if step == Melee.COMBO_HITS else 1.0)
	a.z_index = 6
	shooter.add_child(a)


func _process(delta: float) -> void:
	_time += delta
	if _time >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var sweep := clampf(_time / (LIFE * SWEEP_PART), 0.0, 1.0)
	var fade := 1.0 - clampf((_time - LIFE * SWEEP_PART) / (LIFE * (1.0 - SWEEP_PART)), 0.0, 1.0)
	var start := _angle - _spread * _dir
	var tip := start + 2.0 * _spread * _dir * sweep
	var radius := _reach * (1.0 + INNER) * 0.5
	draw_arc(Vector2.ZERO, radius, start, tip, POINTS, Color(_color, _color.a * fade), _width * fade, true)
	if _bat:
		draw_line(Vector2.from_angle(tip) * _reach * INNER, Vector2.from_angle(tip) * _reach, Color(Palette.BAT_WOOD, fade), BAT_WIDTH, true)
