extends CanvasLayer
## Autoload `RotateGuard`: trên máy cảm ứng, khung nhìn cao hơn rộng (cầm dọc) thì tạm dừng game và hiện lớp phủ
## "Xoay ngang điện thoại để chơi"; xoay ngang lại thì trả đúng trạng thái tạm dừng như trước.
## Trình duyệt di động không khoá được chiều màn hình (trừ Android khi toàn màn hình), nên phải chặn bằng lớp phủ.

const PHONE_SIZE := Vector2(360, 200)  # hình điện thoại nằm ngang (màn dọc thu khung còn ~1/3 nên vẽ to)

var enabled := false
var _was_paused := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	enabled = TouchControls.wanted()
	var shade := ColorRect.new()
	shade.color = Palette.BG
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var col := Ui.vbox(32)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(col)
	var phone := Control.new()
	phone.custom_minimum_size = PHONE_SIZE
	phone.draw.connect(func() -> void:
		phone.draw_rect(Rect2(Vector2.ZERO, PHONE_SIZE), Palette.ACCENT, false, 12.0)
		phone.draw_circle(Vector2(PHONE_SIZE.x - 36, PHONE_SIZE.y / 2), 14, Palette.ACCENT))
	col.add_child(phone)
	phone.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var label := Ui.label("ROTATE_DEVICE", "TitleLabel")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(label)
	get_viewport().size_changed.connect(_check)
	_check.call_deferred()


func _check() -> void:
	var view := get_viewport().get_visible_rect().size
	var portrait := enabled and view.y > view.x
	if portrait == visible:
		return
	if portrait:
		_was_paused = get_tree().paused
		get_tree().paused = true
	else:
		get_tree().paused = _was_paused
	visible = portrait
