class_name TouchIcon
extends Object
## Icon nút cảm ứng vẽ bằng code (cùng cách MapIcon): mỗi hành động một hình riêng để nhận ra nhanh khi đang căng.

enum Kind { FIRE, RELOAD, SWAP, USE, HANDBRAKE, NITRO, HORN, EXIT, PAUSE }

const LINE := 3.0
const SEGMENTS := 28


## Vẽ icon tại `c`; `u` là bán kính cơ bản của hình.
static func draw(ci: CanvasItem, c: Vector2, kind: Kind, u: float, color: Color) -> void:
	match kind:
		Kind.FIRE:  # tâm ngắm
			ci.draw_arc(c, u * 0.7, 0.0, TAU, SEGMENTS, color, LINE, true)
			for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				ci.draw_line(c + d * u * 0.9, c + d * u * 1.35, color, LINE, true)
			ci.draw_circle(c, u * 0.18, color)
		Kind.RELOAD:  # mũi tên vòng
			ci.draw_arc(c, u, deg_to_rad(-60.0), deg_to_rad(240.0), SEGMENTS, color, LINE, true)
			var tip := c + Vector2.from_angle(deg_to_rad(240.0)) * u
			var out := Vector2.from_angle(deg_to_rad(240.0))
			var along := Vector2.from_angle(deg_to_rad(330.0))
			ci.draw_colored_polygon(PackedVector2Array([tip + along * u * 0.6, tip + out * u * 0.45, tip - out * u * 0.45]), color)
		Kind.SWAP:  # hai mũi tên ngược chiều
			_arrow(ci, c + Vector2(0, -u * 0.45), Vector2.RIGHT, u, color)
			_arrow(ci, c + Vector2(0, u * 0.45), Vector2.LEFT, u, color)
		Kind.USE:  # chạm: chấm giữa và vòng lan ra
			ci.draw_circle(c, u * 0.22, color)
			ci.draw_arc(c, u * 0.62, 0.0, TAU, SEGMENTS, color, LINE, true)
			ci.draw_arc(c, u * 1.0, deg_to_rad(200.0), deg_to_rad(340.0), SEGMENTS, color, LINE, true)
		Kind.HANDBRAKE:  # dấu ! trong vòng, hai cung hai bên như má phanh
			ci.draw_arc(c, u * 0.8, 0.0, TAU, SEGMENTS, color, LINE, true)
			ci.draw_line(c + Vector2(0, -u * 0.4), c + Vector2(0, u * 0.1), color, LINE + 1.0, true)
			ci.draw_circle(c + Vector2(0, u * 0.42), LINE * 0.7, color)
			ci.draw_arc(c, u * 1.25, deg_to_rad(150.0), deg_to_rad(210.0), 8, color, LINE, true)
			ci.draw_arc(c, u * 1.25, deg_to_rad(-30.0), deg_to_rad(30.0), 8, color, LINE, true)
		Kind.NITRO:  # tia chớp
			var bolt := PackedVector2Array([Vector2(0.25, -1.0), Vector2(-0.6, 0.1), Vector2(-0.05, 0.1), Vector2(-0.25, 1.0),
				Vector2(0.65, -0.15), Vector2(0.05, -0.15)])
			ci.draw_colored_polygon(Transform2D(0.0, Vector2.ONE * u, 0.0, c) * bolt, color)
		Kind.HORN:  # loa phóng thanh
			var horn := PackedVector2Array([Vector2(-0.9, -0.3), Vector2(-0.3, -0.3), Vector2(0.5, -0.85), Vector2(0.5, 0.85),
				Vector2(-0.3, 0.3), Vector2(-0.9, 0.3)])
			ci.draw_colored_polygon(Transform2D(0.0, Vector2.ONE * u, 0.0, c) * horn, color)
			ci.draw_arc(c + Vector2(0.55, 0) * u, u * 0.55, deg_to_rad(-45.0), deg_to_rad(45.0), 10, color, LINE, true)
		Kind.EXIT:  # cửa và mũi tên đi ra
			ci.draw_polyline(PackedVector2Array([c + Vector2(0.2, -1.0) * u, c + Vector2(-0.8, -1.0) * u,
				c + Vector2(-0.8, 1.0) * u, c + Vector2(0.2, 1.0) * u]), color, LINE, true)
			_arrow(ci, c + Vector2(0.05, 0) * u, Vector2.RIGHT, u, color)
		Kind.PAUSE:  # hai vạch
			for x in [-0.5, 0.2]:
				ci.draw_rect(Rect2(c + Vector2(x, -0.8) * u, Vector2(0.3, 1.6) * u), color)


## Mũi tên nằm ngang dài `u`, chạy theo `dir` (LEFT hoặc RIGHT), tâm ở `c`.
static func _arrow(ci: CanvasItem, c: Vector2, dir: Vector2, u: float, color: Color) -> void:
	var tail := c - dir * u * 0.9
	var tip := c + dir * u * 0.9
	ci.draw_line(tail, tip, color, LINE, true)
	var side := Vector2(0, u * 0.35)
	ci.draw_colored_polygon(PackedVector2Array([tip + dir * u * 0.15, tip - dir * u * 0.4 + side, tip - dir * u * 0.4 - side]), color)
