class_name VirtualStick
extends Control
## Joystick nổi: chạm vào vùng của nó (trừ các nút trong `blocked`) thì tâm joystick đặt ngay dưới ngón tay; kéo để nhấn
## các action theo hướng (có độ lớn). `fire_action` (nếu có) được nhấn khi kéo quá nửa bán kính.
## Lúc chưa chạm vẽ mờ ở góc dưới của vùng (`mirror`: góc phải) để người chơi biết chỗ đặt ngón.

var actions: Array[StringName] = []  # trái, phải, lên, xuống
var fire_action := &""
var mirror := false
var inset := 0.0  # lùi chỗ vẽ mờ vào trong chừng này (chừa chỗ cho nút ở mép)
var blocked: Array[Control] = []
var radius := Tuning.TOUCH_STICK_RADIUS
var knob := Tuning.TOUCH_KNOB
var _touch := -1
var _center := Vector2.ZERO
var _vector := Vector2.ZERO


func setup(dirs: Array[StringName], fire := &"", scale := 1.0) -> VirtualStick:
	actions = dirs
	fire_action = fire
	radius *= scale
	knob *= scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	return self


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1 and get_global_rect().has_point(event.position) and not _is_blocked(event.position):
			_touch = event.index
			_center = event.position - global_position
			_update(event.position)
		elif not event.pressed and event.index == _touch:
			_touch = -1
			_update(global_position + _center)
	elif event is InputEventScreenDrag and event.index == _touch:
		_update(event.position)


## Nút của chính TouchControls (`blocked`) và vùng chạm của HUD (nhóm "touch_block", vd. bản đồ nhỏ).
func _is_blocked(pos: Vector2) -> bool:
	var hit := func(c: Control) -> bool: return c.is_visible_in_tree() and c.get_global_rect().has_point(pos)
	return blocked.any(hit) or get_tree().get_nodes_in_group("touch_block").any(hit)


func _notification(what: int) -> void:
	# Game tạm dừng (hộp thoại, bản đồ, xoay dọc) hoặc joystick bị dựng lại: ngón nhấc ra lúc đó không tới được đây,
	# nên nhả hết action và quên ngón đang giữ, kẻo nhân vật tự đi hoặc súng tự bắn.
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE:
		_touch = -1
		_center = Vector2.ZERO
		_update(global_position)


func _update(pos: Vector2) -> void:
	_vector = ((pos - global_position - _center) / radius).limit_length(1.0)
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
	var side := radius + Tuning.TOUCH_EDGE + inset
	var home := Vector2(size.x - side if mirror else side, size.y - radius - Tuning.TOUCH_EDGE)
	var at := _center if _touch >= 0 else home
	var alpha := 1.0 if _touch >= 0 else 0.6
	draw_circle(at, radius, Color(Palette.PANEL, 0.45 * alpha))
	draw_arc(at, radius, 0, TAU, 48, Color(Palette.TEXT, 0.35 * alpha), 3.0, true)
	draw_circle(at + _vector * radius, knob, Color(Palette.TEXT, 0.55 if _touch >= 0 else 0.3))
