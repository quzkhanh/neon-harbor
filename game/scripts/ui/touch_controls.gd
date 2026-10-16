class_name TouchControls
extends CanvasLayer
## Điều khiển cảm ứng theo vùng ngón cái: joystick nổi di chuyển (nửa trái), kéo nửa phải để ngắm, nút BẮN lớn ở góc
## dưới phải và các nút phụ xếp cung quanh nó (bấm được mà không nhấc ngón). Nút đổi theo ngữ cảnh: đi bộ có
## Nạp đạn / Đổi súng / Dùng (chỉ hiện khi có gì để dùng); trên xe có Phanh tay / Nitro / Xuống xe / Còi. Tạm dừng ở
## giữa mép trên, xa mọi nút khác. Cỡ = Tuning × Game.settings.touch_scale; thuận tay trái thì lật ngang bố cục.
## Cài đặt gọi rebuild() khi đổi. Chỉ hiện trên thiết bị cảm ứng hoặc khi chạy với `-- --touch`.

const ARC := [Vector2(-1, 0), Vector2(-0.7071, -0.7071), Vector2(0, -1)]  # hướng từ nút BẮN tới ba ô cung (bên phải)
const FOOT := [["TOUCH_RELOAD", &"reload"], ["TOUCH_SWAP", &"weapon_next"], ["TOUCH_INTERACT", &"interact"]]
const CAR := [["TOUCH_HANDBRAKE", &"handbrake"], ["TOUCH_NITRO", &"nitro"], ["TOUCH_EXIT", &"interact"]]

static var forced := false  # test bật chế độ cảm ứng khi chạy headless

var move_stick: VirtualStick
var aim_stick: VirtualStick
var buttons := {}  # khoá chú thích -> TouchButton; "FIRE" và "PAUSE" cho hai nút cố định
var _in_car := false


static func wanted() -> bool:
	return forced or DisplayServer.is_touchscreen_available() or "--touch" in OS.get_cmdline_user_args()


func _ready() -> void:
	layer = 12
	add_to_group("touch_controls")
	# Chuột giả lập từ chạm không được tính là nút bắn.
	for e in InputMap.action_get_events(&"fire"):
		if e is InputEventMouseButton:
			InputMap.action_erase_event(&"fire", e)
	get_viewport().size_changed.connect(_layout)
	_build()


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_build()


func _build() -> void:
	var scale: float = Game.settings.touch_scale
	var left_hand: bool = Game.settings.touch_left
	move_stick = _stick([&"move_left", &"move_right", &"move_up", &"move_down"], scale, 0.5 if left_hand else 0.0)
	aim_stick = _stick([&"aim_left", &"aim_right", &"aim_up", &"aim_down"], scale, 0.0 if left_hand else 0.5)
	move_stick.mirror = left_hand
	aim_stick.mirror = not left_hand
	aim_stick.inset = (Tuning.TOUCH_FIRE + Tuning.TOUCH_BUTTON) * scale + 2.0 * Tuning.TOUCH_GAP  # chỗ vẽ mờ không đè cụm nút
	buttons = {}
	_make("FIRE", TouchIcon.Kind.FIRE, "TOUCH_FIRE", &"fire", true)
	_make("PAUSE", TouchIcon.Kind.PAUSE, "", &"pause")
	_make("TOUCH_RELOAD", TouchIcon.Kind.RELOAD, "TOUCH_RELOAD", &"reload")
	_make("TOUCH_SWAP", TouchIcon.Kind.SWAP, "TOUCH_SWAP", &"weapon_next")
	_make("TOUCH_INTERACT", TouchIcon.Kind.USE, "TOUCH_INTERACT", &"interact")
	_make("TOUCH_HANDBRAKE", TouchIcon.Kind.HANDBRAKE, "TOUCH_HANDBRAKE", &"handbrake")
	_make("TOUCH_NITRO", TouchIcon.Kind.NITRO, "TOUCH_NITRO", &"nitro")
	_make("TOUCH_EXIT", TouchIcon.Kind.EXIT, "TOUCH_EXIT", &"interact")
	_make("TOUCH_HORN", TouchIcon.Kind.HORN, "TOUCH_HORN", &"horn")
	for stick in [move_stick, aim_stick]:
		stick.blocked.assign(buttons.values())
		stick.modulate.a = Game.settings.touch_opacity
	_in_car = false
	_layout()


func _make(id: String, icon: TouchIcon.Kind, caption: String, action: StringName, accent := false) -> void:
	var b := TouchButton.new(icon, caption, accent)
	b.modulate.a = Game.settings.touch_opacity
	b.button_down.connect(func() -> void:
		_buzz()
		_send(action, true))
	b.button_up.connect(_send.bind(action, false))
	buttons[id] = b
	add_child(b)


## Đặt vị trí các nút theo kích thước khung nhìn (px của canvas), chế độ đi bộ/lái xe và tay thuận.
func _layout() -> void:
	if buttons.is_empty():
		return
	var scale: float = Game.settings.touch_scale
	var view := get_viewport().get_visible_rect().size
	var flip := -1.0 if Game.settings.touch_left else 1.0
	var fire_side := Tuning.TOUCH_FIRE * scale
	var side := Tuning.TOUCH_BUTTON * scale
	var gap := Tuning.TOUCH_GAP * scale
	var fire_at := Vector2(view.x - Tuning.TOUCH_EDGE - fire_side * 0.5 if flip > 0.0 else Tuning.TOUCH_EDGE + fire_side * 0.5,
		view.y - Tuning.TOUCH_EDGE - fire_side * 0.5)
	_place(buttons.FIRE, fire_at, fire_side)
	_place(buttons.PAUSE, Vector2(view.x * 0.5, Tuning.TOUCH_EDGE * 0.5 + side * 0.5), side)
	var reach := fire_side * 0.5 + side * 0.5 + gap
	for set in [FOOT, CAR]:
		for i in set.size():
			_place(buttons[set[i][0]], fire_at + Vector2(ARC[i].x * flip, ARC[i].y) * reach, side)
	_place(buttons.TOUCH_HORN, fire_at + Vector2(-flip * (reach + side + gap), 0.0), side)
	_show_for_mode()


func _place(b: TouchButton, center: Vector2, side: float) -> void:
	b.set_side(side)
	b.position = center - Vector2.ONE * side * 0.5


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	_in_car = player != null and player.vehicle != null
	_show_for_mode()


## Chỉ hiện nút hợp với đang đi bộ hay đang lái; nút Dùng chỉ hiện khi có gì để dùng.
func _show_for_mode() -> void:
	var city := get_parent()
	var usable: bool = city != null and "interactions" in city and city.interactions.prompt != ""
	for set in [FOOT, CAR]:
		for def in set:
			buttons[def[0]].visible = (set == CAR) == _in_car
	buttons.TOUCH_INTERACT.visible = not _in_car and usable
	buttons.TOUCH_HORN.visible = _in_car


## Joystick chiếm nửa màn hình bắt đầu từ `left` (0 hoặc 0,5).
func _stick(dirs: Array[StringName], scale: float, left: float) -> VirtualStick:
	var s := VirtualStick.new().setup(dirs, scale)
	s.anchor_left = left
	s.anchor_right = left + 0.5
	s.anchor_bottom = 1.0
	add_child(s)
	return s


func _buzz() -> void:
	if Game.settings.touch_haptics:
		Input.vibrate_handheld(Tuning.TOUCH_HAPTIC_MS)


func _send(action: StringName, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	Input.parse_input_event(e)
