class_name SettingsPanel
extends Modal
## Cài đặt: ngôn ngữ (đổi ngay, không khởi động lại), âm lượng nhạc và hiệu ứng.

const LANG_KEYS := {"en": "LANG_EN", "vi": "LANG_VI"}


func _build(content: VBoxContainer) -> void:
	content.custom_minimum_size.x = 520
	content.add_child(Ui.label("SETTINGS_TITLE", "HeaderLabel"))
	content.add_child(Ui.label("SETTINGS_LANGUAGE", "SubLabel", HORIZONTAL_ALIGNMENT_LEFT))
	var langs := Ui.hbox(12)
	content.add_child(langs)
	var group := ButtonGroup.new()
	var focusables: Array[Control] = []
	for lang in I18n.LANGUAGES:
		var b := Ui.button(LANG_KEYS[lang])
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = I18n.language == lang
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(Game.set_setting.bind("lang", lang))
		langs.add_child(b)
		focusables.append(b)
	focusables.append(_slider(content, "SETTINGS_MUSIC", "music"))
	focusables.append(_slider(content, "SETTINGS_SFX", "sfx"))
	var back := Ui.button("SETTINGS_BACK", "AccentButton")
	content.add_child(back)
	back.pressed.connect(close)
	focusables.append(back)
	_link(focusables)


func _slider(content: VBoxContainer, key: String, setting: String) -> HSlider:
	content.add_child(Ui.label(key, "SubLabel", HORIZONTAL_ALIGNMENT_LEFT))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = Game.settings[setting]
	s.focus_mode = Control.FOCUS_ALL
	s.value_changed.connect(func(v: float) -> void: Game.set_setting(setting, v))
	content.add_child(s)
	return s


## Lên/xuống đi qua: hàng ngôn ngữ -> nhạc -> hiệu ứng -> nút quay lại.
func _link(items: Array[Control]) -> void:
	var lang_count := I18n.LANGUAGES.size()
	var rows: Array = [items.slice(0, lang_count)]
	for i in range(lang_count, items.size()):
		rows.append([items[i]])
	for r in rows.size():
		for item in rows[r]:
			item.focus_neighbor_top = item.get_path_to(rows[posmod(r - 1, rows.size())][0])
			item.focus_neighbor_bottom = item.get_path_to(rows[(r + 1) % rows.size()][0])
	items[0].grab_focus.call_deferred()
