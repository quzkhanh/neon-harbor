class_name VirtualStick
extends Control
## Joystick ảo: kéo trong vùng của nó, nhấn các action theo hướng (có độ lớn).
## `fire_action` (nếu có) được nhấn khi kéo quá nửa bán kính.

const RADIUS := 78.0
const KNOB := 34.0

var actions: Array[StringName] = []  # trái, phải, lên, xuống
var fire_action := &""
var _touch := -1
var _center := Vector2.ZERO
var _vector := Vector2.ZERO


func setup(dirs: Array[StringName], fire := &"") -> VirtualStick:
	actions = dirs
	fire_action = fire
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	return self


func _ready() -> void:
	_center = size * 0.5


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1 and get_global_rect().has_point(event.position):
			_touch = event.index
			_center = event.position - global_position
			_update(event.position)
		elif not event.pressed and event.index == _touch:
			_touch = -1
			_center = size * 0.5
			_update(global_position + _center)
	elif event is InputEventScreenDrag and event.index == _touch:
		_update(event.position)


func _update(pos: Vector2) -> void:
	_vector = ((pos - global_position - _center) / RADIUS).limit_length(1.0)
	var strengths := [maxf(-_vector.x, 0.0), maxf(_vector.x, 0.0), maxf(-_vector.y, 0.0), maxf(_vector.y, 0.0)]
	for i in actions.size():
		if strengths[i] > 0.05:
			Input.action_press(actions[i], strengths[i])
		else:
			Input.action_release(actions[i])
	if fire_action != &"":
		if _vector.length() > 0.5:
			Input.action_press(fire_action)
		else:
			Input.action_release(fire_action)
	queue_redraw()


func _draw() -> void:
	draw_circle(_center, RADIUS, Color(Palette.PANEL, 0.45))
	draw_arc(_center, RADIUS, 0, TAU, 48, Color(Palette.TEXT, 0.35), 3.0, true)
	draw_circle(_center + _vector * RADIUS, KNOB, Color(Palette.TEXT, 0.55 if _touch >= 0 else 0.35))
