class_name InputSetup
extends Object
## Đăng ký InputMap bằng code (bàn phím, chuột, tay cầm).

const DEADZONE := 0.25
const WEAPON_SLOTS := 8
const TOUCH_LABELS := {  # nút cảm ứng tương ứng với action (ghi trong gợi ý thay cho phím)
	&"interact": "TOUCH_INTERACT", &"weapon_next": "TOUCH_SWAP", &"reload": "TOUCH_RELOAD",
	&"pause": "TOUCH_PAUSE", &"map": "TOUCH_MAP",
}


static func register() -> void:
	_add(&"move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add(&"move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add(&"move_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add(&"move_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	# Lái xe dùng chung phím di chuyển.
	_add(&"accelerate", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_add(&"brake", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_add(&"steer_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add(&"steer_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add(&"handbrake", [_key(KEY_SPACE), _joy(JOY_BUTTON_B)])
	_add(&"aim_left", [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_add(&"aim_right", [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_add(&"aim_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_add(&"aim_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_add(&"fire", [_mouse(MOUSE_BUTTON_LEFT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_add(&"interact", [_key(KEY_E), _joy(JOY_BUTTON_A)])
	_add(&"weapon_next", [_mouse(MOUSE_BUTTON_WHEEL_DOWN), _key(KEY_Q), _joy(JOY_BUTTON_RIGHT_SHOULDER)])
	_add(&"weapon_prev", [_mouse(MOUSE_BUTTON_WHEEL_UP), _joy(JOY_BUTTON_LEFT_SHOULDER)])
	_add(&"reload", [_key(KEY_R), _joy(JOY_BUTTON_X)])
	_add(&"map", [_key(KEY_M), _key(KEY_TAB), _joy(JOY_BUTTON_BACK)])
	_add(&"pause", [_key(KEY_ESCAPE), _key(KEY_P), _joy(JOY_BUTTON_START)])
	for i in WEAPON_SLOTS:
		_add(StringName("weapon_%d" % (i + 1)), [_key(KEY_1 + i)])


## Tên phím để ghi trong gợi ý ("E", "R"...); trên máy cảm ứng là tên nút cảm ứng (hoặc "" nếu không có nút).
static func key_label(action: StringName) -> String:
	if TouchControls.wanted():
		return TranslationServer.translate(TOUCH_LABELS[action]) if TOUCH_LABELS.has(action) else ""
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return OS.get_keycode_string(e.physical_keycode)
	return ""


static func _add(action: StringName, events: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, DEADZONE)
	for e in events:
		InputMap.action_add_event(action, e)


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e


static func _joy(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e
