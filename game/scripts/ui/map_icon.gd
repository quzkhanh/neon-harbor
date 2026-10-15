class_name MapIcon
extends Object
## Biểu tượng trên minimap và bản đồ thành phố: mỗi loại điểm một hình (khớp chú thích ở MapScreen).

enum Kind { MISSION, SHOP, HOSPITAL, GARAGE, RESPRAY, RACE, JOB, SWEEP, SAFEHOUSE, BUSINESS }

const RADIUS := 8.0
const LEGEND := [
	[Kind.MISSION, Palette.MARKER_MISSION, "LEGEND_MISSION"],
	[Kind.SHOP, Palette.CYAN, "LEGEND_SHOP"],
	[Kind.HOSPITAL, Palette.HEALTH, "LEGEND_HOSPITAL"],
	[Kind.RESPRAY, Palette.ACCENT, "LEGEND_RESPRAY"],
	[Kind.GARAGE, Palette.GOLD, "LEGEND_GARAGE"],
	[Kind.RACE, Palette.ICON_RACE, "LEGEND_RACE"],
	[Kind.JOB, Palette.ICON_JOB, "LEGEND_JOB"],
	[Kind.SWEEP, Palette.ICON_SWEEP, "LEGEND_SWEEP"],
	[Kind.SAFEHOUSE, Palette.MONEY, "LEGEND_SAFEHOUSE"],
	[Kind.BUSINESS, Palette.ICON_BUSINESS, "LEGEND_BUSINESS"],
]


static func draw(ci: CanvasItem, pos: Vector2, kind: Kind, color: Color, r := RADIUS) -> void:
	ci.draw_circle(pos, r + 2.0, Palette.OUTLINE)
	ci.draw_circle(pos, r, color)
	var ink := Palette.BG
	var u := r / 8.0
	match kind:
		Kind.SHOP:  # khẩu súng lục nhìn ngang
			ci.draw_rect(Rect2(pos + Vector2(-5, -3) * u, Vector2(10, 3) * u), ink)
			ci.draw_rect(Rect2(pos + Vector2(-5, -1) * u, Vector2(3, 5) * u), ink)
		Kind.HOSPITAL:  # chữ thập
			ci.draw_rect(Rect2(pos + Vector2(-1.5, -5) * u, Vector2(3, 10) * u), Color.WHITE)
			ci.draw_rect(Rect2(pos + Vector2(-5, -1.5) * u, Vector2(10, 3) * u), Color.WHITE)
		Kind.RESPRAY:  # giọt sơn
			ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -5) * u, pos + Vector2(3.5, 1) * u, pos + Vector2(-3.5, 1) * u]), Color.WHITE)
			ci.draw_circle(pos + Vector2(0, 1.5) * u, 3.5 * u, Color.WHITE)
		Kind.GARAGE:  # cửa cuốn
			for i in 3:
				ci.draw_rect(Rect2(pos + Vector2(-4.5, -4 + i * 3) * u, Vector2(9, 1.6) * u), ink)
		Kind.MISSION:  # chấm giữa
			ci.draw_circle(pos, 3.0 * u, Color.WHITE)
		Kind.RACE:  # cờ ca rô
			for i in 4:
				var cell := Vector2(i % 2, i >> 1)
				ci.draw_rect(Rect2(pos + (Vector2(-4, -4) + cell * 4.0) * u, Vector2(4, 4) * u), ink if (i % 2 + (i >> 1)) % 2 == 0 else Color.WHITE)
		Kind.JOB:  # thùng hàng
			ci.draw_rect(Rect2(pos + Vector2(-4.5, -4) * u, Vector2(9, 8) * u), ink)
			ci.draw_rect(Rect2(pos + Vector2(-1, -4) * u, Vector2(2, 8) * u), Color.WHITE)
		Kind.SWEEP:  # tâm ngắm
			ci.draw_arc(pos, 4.0 * u, 0.0, TAU, 16, ink, 1.5 * u)
			ci.draw_rect(Rect2(pos + Vector2(-0.75, -6) * u, Vector2(1.5, 12) * u), ink)
			ci.draw_rect(Rect2(pos + Vector2(-6, -0.75) * u, Vector2(12, 1.5) * u), ink)
		Kind.SAFEHOUSE:  # ngôi nhà
			ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -5.5) * u, pos + Vector2(5.5, -0.5) * u, pos + Vector2(-5.5, -0.5) * u]), ink)
			ci.draw_rect(Rect2(pos + Vector2(-3.5, -0.5) * u, Vector2(7, 5) * u), ink)
		Kind.BUSINESS:  # cột biểu đồ đi lên
			for i in 3:
				ci.draw_rect(Rect2(pos + Vector2(-4.5 + i * 3.5, 4 - (i + 1) * 2.8) * u, Vector2(2.4, (i + 1) * 2.8) * u), ink)
