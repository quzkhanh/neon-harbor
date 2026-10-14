class_name KillMark
extends Node2D
## Dấu X đỏ bật lên trên xác khi người chơi hạ gục, rồi mờ dần.

const HALF := 11.0
const WIDTH := 5.0
const OUTLINE_EXTRA := 3.0
const RISE := 18.0


func _ready() -> void:
	z_index = 23
	scale = Vector2.ONE * 1.8
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:y", position.y - RISE, Tuning.KILL_MARK_TIME)
	t.parallel().tween_property(self, "modulate:a", 0.0, Tuning.KILL_MARK_TIME).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)


func _draw() -> void:
	for pass_color in [[Palette.OUTLINE, WIDTH + OUTLINE_EXTRA], [Palette.KILL_MARK, WIDTH]]:
		draw_line(Vector2(-HALF, -HALF), Vector2(HALF, HALF), pass_color[0], pass_color[1], true)
		draw_line(Vector2(-HALF, HALF), Vector2(HALF, -HALF), pass_color[0], pass_color[1], true)
