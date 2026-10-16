class_name TouchButton
extends Control
## Nút tròn cảm ứng tự xử lý chạm đa điểm: Godot chỉ giả lập chuột cho ngón đầu tiên, nên `Button` thường không nhận
## ngón thứ hai lúc ngón kia đang giữ joystick. Giữ nút tới khi nhấc đúng ngón đã bấm (trượt ra ngoài vẫn giữ, để
## đang bắn mà trượt ngón không bị ngắt). Icon vẽ bằng code (TouchIcon) ở nửa trên, chú thích (khoá dịch) ở nửa dưới.

signal button_down
signal button_up

const CAPTION_AT := 0.84  # vị trí dòng chú thích theo chiều cao nút
const ICON_AT := 0.42
const ICON_SIZE := 0.2  # bán kính icon theo cạnh nút
const HIT_SLOP := 1.1  # vùng chạm rộng hơn hình vẽ một chút
const NONE := -2
const MOUSE := -1

var kind: TouchIcon.Kind
var caption := ""  # khoá dịch; rỗng thì chỉ có icon
var accent := false  # viền nổi bật (nút BẮN)
var held := false
var _finger := NONE


func _init(icon_kind: TouchIcon.Kind, caption_key: String, accented := false) -> void:
	kind = icon_kind
	caption = caption_key
	accent = accented
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_side(side: float) -> void:
	custom_minimum_size = Vector2.ONE * side
	size = Vector2.ONE * side
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		_release()
		return
	if event is InputEventScreenTouch:
		if event.pressed and _finger == NONE and _hit(event.position):
			_press(event.index)
		elif not event.pressed and event.index == _finger:
			_release()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed and _finger == NONE and _hit(event.position):
			_press(MOUSE)
		elif not event.pressed and _finger == MOUSE:
			_release()


func _hit(pos: Vector2) -> bool:
	return pos.distance_to(global_position + size * 0.5) <= minf(size.x, size.y) * 0.5 * HIT_SLOP


func _press(finger: int) -> void:
	_finger = finger
	held = true
	button_down.emit()
	queue_redraw()


func _release() -> void:
	if _finger == NONE:
		return
	_finger = NONE
	held = false
	button_up.emit()
	queue_redraw()


func _draw() -> void:
	var side := minf(size.x, size.y)
	var center := size * 0.5
	var edge := Palette.ACCENT if accent or held else Palette.BORDER
	draw_circle(center, side * 0.5, Palette.ACCENT_DARK if held else Color(Palette.PANEL, 0.75))
	draw_arc(center, side * 0.5 - 2.0, 0.0, TAU, 48, edge, 4.0 if accent else 3.0, true)
	var icon_at := Vector2(center.x, size.y * (ICON_AT if caption != "" else 0.5))
	TouchIcon.draw(self, icon_at, kind, side * ICON_SIZE, Palette.TEXT)
	if caption != "":
		draw_string(get_theme_font("font", "Label"), Vector2(0, size.y * CAPTION_AT), tr(caption), HORIZONTAL_ALIGNMENT_CENTER, size.x,
			get_theme_font_size("font_size", "TouchButton"), Palette.TEXT_DIM)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()
	elif what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE:
		_release()  # ngón nhấc ra lúc game tạm dừng (hộp thoại, bản đồ) không tới được đây: nhả nút kẻo kẹt
