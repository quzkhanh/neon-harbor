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
	var back := Ui.button("SAFEHOUSE_LEAVE")
	back.pressed.connect(close)
	content.add_child(back)
	buttons.append(back)
	Ui.focus_chain.call_deferred(buttons.filter(func(b: Button) -> bool: return not b.disabled))
