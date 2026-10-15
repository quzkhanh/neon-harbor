class_name TouchControls
extends CanvasLayer
## Điều khiển cảm ứng: joystick nổi di chuyển (nửa trái) và ngắm/bắn (nửa phải), nút tròn Dùng / Đổi súng / Nạp đạn
## dọc mép phải, nút tạm dừng bên trái nút trên cùng. Cỡ = Tuning × Game.settings.touch_scale; Cài đặt gọi rebuild() khi đổi cỡ.
## Chỉ hiện trên thiết bị cảm ứng hoặc khi chạy với `-- --touch`.

const BUTTONS_TOP := 170.0  # dưới hàng sao và thẻ súng
const BUTTONS := [["TOUCH_INTERACT", &"interact"], ["TOUCH_SWAP", &"weapon_next"], ["TOUCH_RELOAD", &"reload"],
	["TOUCH_NITRO", &"nitro"]]

static var forced := false  # test bật chế độ cảm ứng khi chạy headless

var _nitro: Button  # chỉ hiện khi đang lái xe


static func wanted() -> bool:
	return forced or DisplayServer.is_touchscreen_available() or "--touch" in OS.get_cmdline_user_args()


func _ready() -> void:
	layer = 12
	add_to_group("touch_controls")
	# Chuột giả lập từ chạm không được tính là nút bắn.
	for e in InputMap.action_get_events(&"fire"):
		if e is InputEventMouseButton:
			InputMap.action_erase_event(&"fire", e)
	_build()


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_build()


func _build() -> void:
	var scale: float = Game.settings.touch_scale
	_stick([&"move_left", &"move_right", &"move_up", &"move_down"], &"", scale, 0.0)
	var aim := _stick([&"aim_left", &"aim_right", &"aim_up", &"aim_down"], &"fire", scale, 0.5)
	aim.mirror = true
	aim.inset = (Tuning.TOUCH_BUTTON + Tuning.TOUCH_GAP) * scale  # chỗ vẽ mờ không đè cột nút
	var col := Ui.vbox(int(Tuning.TOUCH_GAP * scale))
	col.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	col.offset_right = -Tuning.TOUCH_EDGE
	col.offset_top = BUTTONS_TOP
	add_child(col)
	for def in BUTTONS:
		var b := _button(def[0], Tuning.TOUCH_BUTTON * scale)
		b.button_down.connect(_send.bind(def[1], true))
		b.button_up.connect(_send.bind(def[1], false))
		col.add_child(b)
		aim.blocked.append(b)
		if def[1] == &"nitro":
			_nitro = b
	var pause := _button("TOUCH_PAUSE", Tuning.TOUCH_BUTTON * scale)
	pause.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pause.offset_right = -Tuning.TOUCH_EDGE - (Tuning.TOUCH_BUTTON + Tuning.TOUCH_GAP) * scale
	pause.offset_top = BUTTONS_TOP
	pause.pressed.connect(_send.bind(&"pause", true))
	add_child(pause)
	aim.blocked.append(pause)


func _process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if is_instance_valid(_nitro):
		_nitro.visible = p != null and p.vehicle != null


## Joystick chiếm nửa màn hình bắt đầu từ `left` (0 hoặc 0,5).
func _stick(dirs: Array[StringName], fire: StringName, scale: float, left: float) -> VirtualStick:
	var s := VirtualStick.new().setup(dirs, fire, scale)
	s.anchor_left = left
	s.anchor_right = left + 0.5
	s.anchor_bottom = 1.0
	add_child(s)
	return s


func _button(key: String, side: float) -> Button:
	var b := Ui.button(key, "TouchButton")
	b.custom_minimum_size = Vector2.ONE * side
	b.focus_mode = Control.FOCUS_NONE
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return b


func _send(action: StringName, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	Input.parse_input_event(e)
