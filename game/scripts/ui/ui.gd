class_name Ui
extends Object
## Hàm dựng control dùng chung. Chữ luôn là khoá dịch; Godot tự dịch khi đổi ngôn ngữ.


static func label(key: String, variation := "", align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = key
	l.theme_type_variation = variation
	l.horizontal_alignment = align
	return l


## Nhãn có tham số (xem LiveLabel).
static func live_label(key: String, params: Callable, variation := "", align := HORIZONTAL_ALIGNMENT_CENTER) -> LiveLabel:
	var l := LiveLabel.new()
	l.theme_type_variation = variation
	l.horizontal_alignment = align
	return l.setup(key, params)


static func button(key: String, variation := "") -> Button:
	var b := Button.new()
	b.text = key
	b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(Sfx.play.bind("ui_click"))
	b.focus_entered.connect(Sfx.play.bind("ui_move", -8.0))
	return b


static func vbox(separation := 12) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	return b


static func hbox(separation := 12) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	return b


static func texture(path: String, size := Vector2.ZERO) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path) if ResourceLoader.exists(path) else null
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = size
	return t


## Lớp phủ toàn màn hình: nền mờ + panel giữa màn. Trả về [layer, box nội dung].
static func modal(layer_index: int, width := 0.0) -> Array:
	var layer := CanvasLayer.new()
	layer.layer = layer_index
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Palette.DIM_SCREEN
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	center.add_child(panel)
	var box := vbox(16)
	panel.add_child(box)
	return [layer, box]


## Nối focus dọc cho danh sách nút và focus nút đầu tiên đang hiện.
static func focus_chain(buttons: Array) -> void:
	var visible := buttons.filter(func(b: Control) -> bool: return b.visible)
	for i in visible.size():
		var b: Control = visible[i]
		b.focus_neighbor_top = b.get_path_to(visible[posmod(i - 1, visible.size())])
		b.focus_neighbor_bottom = b.get_path_to(visible[posmod(i + 1, visible.size())])
	if visible.size() > 0:
		visible[0].grab_focus.call_deferred()
