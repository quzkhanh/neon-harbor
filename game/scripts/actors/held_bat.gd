class_name HeldBat
extends Node2D
## Cây gậy cầm trên tay người chơi lúc đã chọn gậy. Là con của `body` nên xoay, nhún và nhoài theo thân; ẩn trong lúc
## vung vì lúc đó SwingArc vẽ cú quét.

const GRIP := Vector2(14, 12.5)  # bàn tay dưới của tư thế "hold" (so với tâm nhân vật, mặt hướng +x)
const ANGLE := deg_to_rad(-38.0)

var equipped := false
var _human: Human


func _init(human: Human) -> void:
	_human = human
	z_index = 2


func _process(_delta: float) -> void:
	visible = equipped and not _human.is_swinging()


func _draw() -> void:
	BatShape.draw(self, GRIP, ANGLE)
