class_name SettingsPanel
extends Modal
## Cài đặt: ngôn ngữ (đổi ngay, không khởi động lại), kiểu lái xe, hướng dẫn người mới, âm lượng nhạc và hiệu ứng.

const LANG_KEYS := {"en": "LANG_EN", "vi": "LANG_VI"}
const STEERING_KEYS := {DriveInput.SCREEN: "STEERING_SCREEN", DriveInput.CLASSIC: "STEERING_CLASSIC"}
const TUTORIAL_KEYS := {true: "TUTORIAL_ON", false: "TUTORIAL_OFF"}


func _build(content: VBoxContainer) -> void:
	content.custom_minimum_size.x = 560
	content.add_child(Ui.label("SETTINGS_TITLE", "HeaderLabel"))
	var rows: Array = [
		_choices(content, "SETTINGS_LANGUAGE", "lang", LANG_KEYS, I18n.language),
		_choices(content, "SETTINGS_STEERING", "steering", STEERING_KEYS, Game.settings.steering),
		_choices(content, "SETTINGS_TUTORIAL", "tutorial", TUTORIAL_KEYS, Game.settings.tutorial),
		[_slider(content, "SETTINGS_MUSIC", "music")],
		[_slider(content, "SETTINGS_SFX", "sfx")],
	]
	var back := Ui.button("SETTINGS_BACK", "AccentButton")
	content.add_child(back)
	back.pressed.connect(close)
	rows.append([back])
	_link(rows)


## Hàng nút chọn một trong nhiều giá trị (`options`: giá trị -> khoá dịch).
func _choices(content: VBoxContainer, title_key: String, setting: String, options: Dictionary, current: Variant) -> Array:
	content.add_child(Ui.label(title_key, "SubLabel", HORIZONTAL_ALIGNMENT_LEFT))
	var row := Ui.hbox(12)
	content.add_child(row)
	var group := ButtonGroup.new()
	var buttons: Array = []
	for value in options:
		var b := Ui.button(options[value])
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = current == value
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(Game.set_setting.bind(setting, value))
		row.add_child(b)
		buttons.append(b)
	return buttons


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


## Lên/xuống đi qua từng hàng (hàng nhiều nút thì vào nút đầu); trái/phải trong hàng là mặc định.
func _link(rows: Array) -> void:
	for r in rows.size():
		for item in rows[r]:
			item.focus_neighbor_top = item.get_path_to(rows[posmod(r - 1, rows.size())][0])
			item.focus_neighbor_bottom = item.get_path_to(rows[(r + 1) % rows.size()][0])
	rows[0][0].grab_focus.call_deferred()
