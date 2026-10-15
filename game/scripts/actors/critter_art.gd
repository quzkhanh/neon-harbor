class_name CritterArt
extends Object
## Hình thú vật vẽ bằng code (nhìn từ trên xuống, mặt hướng +x): không có sprite thú trong `vendor/`.
## `t`: thời gian chạy của hoạt ảnh (bước chân, vỗ cánh); `lift`: 0 trên đất, 1 đang bay (bóng tách khỏi thân).

## Bóng đổ cùng hướng với bóng nhà (`Tuning.SHADOW_OFFSET`): sát chân khi đứng, xa dần khi bay lên.
const GROUND_DROP := 0.1
const AIR_DROP := 0.9
const SHADOW_SIZE := {"pigeon": Vector2(6.5, 3.8), "gull": Vector2(7.0, 9.0), "cat": Vector2(9.0, 4.0), "dog": Vector2(11.0, 5.0), "crab": Vector2(4.5, 6.5)}


static func draw(c: Node2D, kind: String, coat: Color, t: float, lift: float) -> void:
	var drop := (Tuning.SHADOW_OFFSET * lerpf(GROUND_DROP, AIR_DROP, lift)).rotated(-c.rotation) / c.scale
	var shadow: Vector2 = SHADOW_SIZE[kind]
	c.draw_colored_polygon(Shapes.ellipse(drop, shadow.x, shadow.y), Palette.CRITTER_SHADOW)
	match kind:
		"pigeon": _pigeon(c, t, lift)
		"gull": _gull(c, t)
		"cat": _cat(c, coat, t)
		"dog": _dog(c, coat, t)
		"crab": _crab(c, t)


static func _pigeon(c: CanvasItem, t: float, lift: float) -> void:
	var bob := 0.8 * sin(t * 9.0) * (1.0 - lift)
	_tail(c, 3.0, 7.8, 2.8, Palette.PIGEON_WING)
	if lift > 0.0:
		var span := 8.0 * (0.75 + 0.25 * sin(t * 38.0))
		for side in [-1.0, 1.0]:
			_wing(c, Vector2(1.0, 1.4 * side), span * side, Palette.PIGEON_WING, Palette.WING_BAR)
	Shapes.oval(c, Vector2.ZERO, 5.5, 4.0, Palette.PIGEON_BODY)
	if lift == 0.0:
		for side in [-1.0, 1.0]:
			Shapes.oval(c, Vector2(-1.2, 1.9 * side), 4.4, 2.0, Palette.PIGEON_WING)
			c.draw_line(Vector2(-2.6, 0.8 * side), Vector2(-2.9, 3.0 * side), Palette.WING_BAR, 0.9, true)
	Shapes.oval(c, Vector2(3.6 + bob, 0), 2.6, 2.6, Palette.PIGEON_NECK)
	var head := Vector2(5.6 + bob, 0)
	Shapes.oval(c, head, 2.0, 1.9, Palette.PIGEON_HEAD)
	_beak(c, head + Vector2(1.6, 0), 1.7, 0.7, Palette.PIGEON_BEAK)


static func _gull(c: CanvasItem, t: float) -> void:
	var span := 15.0 * (0.8 + 0.2 * sin(t * 6.0))
	_tail(c, 4.5, 9.0, 2.4, Palette.GULL_BODY)
	for side in [-1.0, 1.0]:
		_wing(c, Vector2(1.5, 1.8 * side), span * side, Palette.GULL_WING, Palette.GULL_TIP)
	Shapes.oval(c, Vector2.ZERO, 7.0, 3.0, Palette.GULL_BODY)
	var head := Vector2(6.4, 0)
	Shapes.oval(c, head, 2.4, 2.2, Palette.GULL_BODY)
	_beak(c, head + Vector2(2.0, 0), 2.4, 0.8, Palette.BEAK)


## Cánh xoè quét về sau: gốc ở `root`, `span` có dấu theo bên trái/phải; đầu cánh tô màu `tip`.
static func _wing(c: CanvasItem, root: Vector2, span: float, color: Color, tip: Color) -> void:
	var lead_root := root + Vector2(1.5, 0)
	var lead_tip := root + Vector2(-1.5, span)
	var trail_tip := root + Vector2(-4.5, span * 0.92)
	var trail_root := root + Vector2(-3.5, 0)
	Shapes.polygon(c, PackedVector2Array([lead_root, lead_tip, trail_tip, trail_root]), color)
	Shapes.polygon(c, PackedVector2Array([lead_root.lerp(lead_tip, 0.72), lead_tip, trail_tip, trail_root.lerp(trail_tip, 0.72)]), tip)


## Đuôi xoè hình quạt sau thân chim.
static func _tail(c: CanvasItem, from: float, to: float, half: float, color: Color) -> void:
	Shapes.polygon(c, PackedVector2Array([Vector2(-from, -half * 0.5), Vector2(-to, -half), Vector2(-to - 0.6, 0), Vector2(-to, half), Vector2(-from, half * 0.5)]), color)


static func _beak(c: CanvasItem, base: Vector2, length: float, half: float, color: Color) -> void:
	Shapes.polygon(c, PackedVector2Array([base + Vector2(0, -half), base + Vector2(length, 0), base + Vector2(0, half)]), color)


static func _cat(c: CanvasItem, coat: Color, t: float) -> void:
	var sway := sin(t * 3.0)
	_paws(c, coat, t, 6.0, 3.6)
	Shapes.stroke(c, PackedVector2Array([Vector2(-6.0, 0), Vector2(-9.5, 1.4 * sway), Vector2(-12.5, 3.2 * sway + 1.2)]), coat, 1.8)
	Shapes.oval(c, Vector2.ZERO, 7.0, 3.8, coat)
	var stripe := coat.darkened(0.22)
	for x in [-3.6, -1.2, 1.2]:
		c.draw_line(Vector2(x + 0.5, -2.8), Vector2(x - 0.5, 2.8), stripe, 0.9, true)
	var head := Vector2(7.4, 0)
	Shapes.oval(c, head, 3.0, 2.8, coat.lightened(0.06))
	for side in [-1.0, 1.0]:
		Shapes.polygon(c, PackedVector2Array([head + Vector2(-1.6, 1.2 * side), head + Vector2(0.8, 1.9 * side), head + Vector2(-0.9, 4.0 * side)]), coat.darkened(0.08))
	Shapes.oval(c, head + Vector2(2.2, 0), 1.2, 1.4, coat.lightened(0.3))
	c.draw_circle(head + Vector2(3.2, 0), 0.6, Palette.CAT_NOSE)
	_eyes(c, head + Vector2(1.3, 0), 1.2)


static func _dog(c: CanvasItem, coat: Color, t: float) -> void:
	_paws(c, coat, t, 7.0, 3.8)
	Shapes.stroke(c, PackedVector2Array([Vector2(-8.5, 0), Vector2(-12.0, 2.6 * sin(t * 16.0))]), coat, 2.0)
	Shapes.oval(c, Vector2.ZERO, 9.5, 4.2, coat)
	c.draw_line(Vector2(7.4, -2.6), Vector2(7.4, 2.6), Palette.DOG_COLLAR, 1.4, true)
	var head := Vector2(10.8, 0)
	Shapes.oval(c, head + Vector2(3.0, 0), 2.6, 1.6, coat.lightened(0.22))
	Shapes.oval(c, head, 3.0, 2.8, coat.lightened(0.06))
	for side in [-1.0, 1.0]:
		Shapes.oval(c, head + Vector2(-1.0, 2.5 * side), 2.6, 1.1, coat.darkened(0.35), 0.25 * side)
	c.draw_circle(head + Vector2(5.4, 0), 0.9, Palette.CRITTER_EYE)
	_eyes(c, head + Vector2(1.2, 0), 1.3)


## Bốn bàn chân ló ra hai bên thân, đổi nhịp khi đi.
static func _paws(c: CanvasItem, coat: Color, t: float, reach: float, width: float) -> void:
	var step := 2.2 * sin(t * 14.0)
	for end in [1.0, -1.0]:
		for side in [1.0, -1.0]:
			Shapes.oval(c, Vector2(reach * end + step * end * side, width * side), 1.5, 1.1, coat.darkened(0.15))


static func _eyes(c: CanvasItem, at: Vector2, gap: float) -> void:
	for side in [-1.0, 1.0]:
		c.draw_circle(at + Vector2(0, gap * side), 0.55, Palette.CRITTER_EYE)


static func _crab(c: CanvasItem, t: float) -> void:
	var scuttle := sin(t * 18.0)
	var shell := Palette.CRAB_BODY
	var leg_color := shell.darkened(0.3)
	for side in [-1.0, 1.0]:
		for leg in 3:
			var x := -2.4 + leg * 2.0
			var swing := scuttle * (0.8 if leg % 2 == 0 else -0.8)
			c.draw_polyline(PackedVector2Array([Vector2(x, 3.6 * side), Vector2(x - 0.8 + swing, 6.4 * side), Vector2(x - 2.0 + swing, 7.6 * side)]), leg_color, 0.9, true)
		c.draw_line(Vector2(2.0, 3.0 * side), Vector2(4.4, 4.4 * side), leg_color, 1.1, true)
		Shapes.oval(c, Vector2(5.6, 4.6 * side), 2.2, 1.5, shell.lightened(0.08), 0.35 * side)
		c.draw_line(Vector2(6.0, 4.6 * side), Vector2(7.8, 4.2 * side), shell.darkened(Shapes.OUTLINE_DARKEN), 0.6, true)
		c.draw_line(Vector2(3.0, 1.3 * side), Vector2(4.4, 1.6 * side), leg_color, 0.6, true)
	Shapes.oval(c, Vector2.ZERO, 4.0, 5.2, shell)
	Shapes.oval(c, Vector2(0.6, 0), 2.2, 3.0, shell.lightened(0.15), 0.0, false)
	_eyes(c, Vector2(4.5, 0), 1.6)
