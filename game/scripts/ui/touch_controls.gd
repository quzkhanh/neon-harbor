class_name TouchControls
extends CanvasLayer
## Điều khiển cảm ứng: joystick di chuyển (trái), joystick ngắm/bắn (phải), nút lên xe, đổi súng, nạp đạn, tạm dừng.
## Chỉ hiện trên thiết bị cảm ứng hoặc khi chạy với `-- --touch`.

const STICK_ZONE := Vector2(300, 300)
const BUTTON_SIZE := Vector2(110, 64)
const EDGE := 20.0
const PAUSE_RIGHT := 180.0  # chừa chỗ cho hàng sao truy nã
const BUTTONS := [["TOUCH_INTERACT", &"interact"], ["TOUCH_SWAP", &"weapon_next"], ["TOUCH_RELOAD", &"reload"]]


static func wanted() -> bool:
	return DisplayServer.is_touchscreen_available() or "--touch" in OS.get_cmdline_user_args()


func _ready() -> void:
	layer = 12
	add_to_group("touch_controls")
	# Chuột giả lập từ chạm không được tính là nút bắn.
	for e in InputMap.action_get_events(&"fire"):
		if e is InputEventMouseButton:
			InputMap.action_erase_event(&"fire", e)
	var move := VirtualStick.new().setup([&"move_left", &"move_right", &"move_up", &"move_down"])
	move.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	move.position = Vector2(20, -STICK_ZONE.y - 20)
	move.size = STICK_ZONE
	add_child(move)
	var aim := VirtualStick.new().setup([&"aim_left", &"aim_right", &"aim_up", &"aim_down"], &"fire")
	aim.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	aim.position = Vector2(-STICK_ZONE.x - 20, -STICK_ZONE.y - 20)
	aim.size = STICK_ZONE
	add_child(aim)
	var col := Ui.vbox(10)
	col.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	col.offset_right = -EDGE
	col.offset_top = -BUTTON_SIZE.y * 2.0
	add_child(col)
	for def in BUTTONS:
		var b := Ui.button(def[0])
		b.custom_minimum_size = BUTTON_SIZE
		b.focus_mode = Control.FOCUS_NONE
		b.button_down.connect(_send.bind(def[1], true))
		b.button_up.connect(_send.bind(def[1], false))
		col.add_child(b)
	var pause := Ui.button("TOUCH_PAUSE", "FlatButton")
	pause.focus_mode = Control.FOCUS_NONE
	pause.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pause.offset_right = -PAUSE_RIGHT
	pause.offset_top = EDGE
	pause.pressed.connect(_send.bind(&"pause", true))
	add_child(pause)


func _send(action: StringName, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	Input.parse_input_event(e)
