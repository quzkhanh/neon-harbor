class_name Emote
extends Node2D
## Bong bóng cảm xúc trên đầu một người: "!" (giật mình), "?" (thắc mắc), gân giận, giọt mồ hôi sợ.
## Vẽ bằng hình học (không cần font). Mỗi người chỉ một bong bóng: hiện cái mới thì cái cũ biến mất.

enum Kind { ALERT, QUESTION, ANGRY, FEAR }

const OFFSET := Vector2(14, -42)
const RADIUS := 12.0
const OUTLINE := 2.5
const INK := 3.0
const LIFE := 1.4
const NODE_NAME := "Emote"

var kind := Kind.ALERT


static func show_on(who: Node2D, emote_kind: Kind) -> void:
	var old := who.get_node_or_null(NODE_NAME)
	if old:
		old.free()
	var e := Emote.new()
	e.name = NODE_NAME
	e.kind = emote_kind
	e.position = OFFSET
	e.z_index = 22
	e.z_as_relative = false
	e.scale = Vector2.ONE * 0.2
	who.add_child(e)


func _ready() -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(LIFE)
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(queue_free)


func _draw() -> void:
	var tail := PackedVector2Array([Vector2(-7, 7), Vector2(-3, 10), Vector2(-12, 15)])
	draw_colored_polygon(tail, Palette.OUTLINE)
	draw_circle(Vector2.ZERO, RADIUS + OUTLINE, Palette.OUTLINE)
	draw_circle(Vector2.ZERO, RADIUS, Palette.EMOTE_BUBBLE)
	match kind:
		Kind.ALERT:
			draw_line(Vector2(0, -7), Vector2(0, 2), Palette.EMOTE_ALERT, INK + 0.5, true)
			draw_circle(Vector2(0, 6.5), 2.0, Palette.EMOTE_ALERT)
		Kind.QUESTION:
			draw_arc(Vector2(0, -3), 4.5, PI, PI * 2.5, 12, Palette.OUTLINE, INK, true)
			draw_line(Vector2(0, 1.5), Vector2(0, 3), Palette.OUTLINE, INK, true)
			draw_circle(Vector2(0, 7), 1.8, Palette.OUTLINE)
		Kind.ANGRY:
			for i in 4:
				var corner := PI * 0.25 + PI * 0.5 * i
				draw_arc(Vector2.from_angle(corner) * 6.0, 4.0, corner + PI - 0.9, corner + PI + 0.9, 6, Palette.EMOTE_ANGRY, INK, true)
		Kind.FEAR:
			draw_colored_polygon(PackedVector2Array([Vector2(0, -8), Vector2(-4.2, 1), Vector2(4.2, 1)]), Palette.EMOTE_FEAR)
			draw_circle(Vector2(0, 2), 4.5, Palette.EMOTE_FEAR)
