class_name Wardrobe
extends Modal
## Tủ đồ ở nhà an toàn: chọn trang phục cho Jay (skin Kenney). Trang phục cuối chỉ mở sau khi xong cốt truyện.

const PORTRAIT := Vector2(72, 72)


func _build(content: VBoxContainer) -> void:
	content.custom_minimum_size.x = 560
	content.add_child(Ui.label("WARDROBE_TITLE", "HeaderLabel"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	var buttons := []
	for skin in Tuning.SKINS:
		var b := Button.new()
		b.icon = load(Human.CHAR_DIR % [skin, "stand"])
		b.expand_icon = true
		b.custom_minimum_size = PORTRAIT * 1.4
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.disabled = not Game.skin_unlocked(skin)
		b.modulate = Palette.GOLD if skin == Game.skin else Color.WHITE
		b.pressed.connect(func() -> void:
			Game.set_skin(skin)
			close(skin))
		grid.add_child(b)
		buttons.append(b)
	var style := _hair_button("WARDROBE_HAIR", "HAIR_STYLE", Hair.STYLES, Game.hair, func(i: int) -> void: Game.set_hair(Hair.STYLES[i], Game.hair_color))
	var tint := _hair_button("WARDROBE_HAIR_COLOR", "HAIR_COLOR", range(Palette.HAIR.size()), Game.hair_color, func(i: int) -> void: Game.set_hair(Game.hair, i))
	content.add_child(style)
	content.add_child(tint)
	buttons.append_array([style, tint])
	var back := Ui.button("SAFEHOUSE_LEAVE")
	back.pressed.connect(close)
	content.add_child(back)
	buttons.append(back)
	Ui.focus_chain.call_deferred(buttons.filter(func(b: Button) -> bool: return not b.disabled))


## Nút xoay vòng qua `options`, hiện tên lựa chọn hiện tại (khoá nhóm `prefix_<số thứ tự từ 1>`) và gọi `apply(chỉ số)`.
func _hair_button(key: String, prefix: String, options: Array, current: Variant, apply: Callable) -> Button:
	var b := Ui.button("")
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var index := [options.find(current)]  # lambda bắt biến theo giá trị: giữ trong mảng để cộng dồn qua các lần bấm
	var refresh := func() -> void:
		b.text = I18n.fmt(key, {"name": tr("%s_%d" % [prefix, index[0] + 1])})
	refresh.call()
	b.pressed.connect(func() -> void:
		index[0] = (index[0] + 1) % options.size()
		apply.call(index[0])
		refresh.call())
	return b
