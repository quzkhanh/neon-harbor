class_name TouchSettings
extends Modal
## Điều khiển cảm ứng (mở từ Cài đặt): cỡ nút, độ đậm, thuận tay trái, rung. Đổi là dựng lại nút ngay để thấy kết quả.


func _build(content: VBoxContainer) -> void:
	content.custom_minimum_size.x = 560
	content.add_child(Ui.label("SETTINGS_TOUCH", "HeaderLabel"))
	var rebuild := func(_v: Variant) -> void: get_tree().call_group("touch_controls", "rebuild")
	var size := SettingsPanel.slider(content, "SETTINGS_TOUCH_SIZE", "touch_scale", Tuning.TOUCH_SCALE_RANGE.x, Tuning.TOUCH_SCALE_RANGE.y)
	size.value_changed.connect(rebuild)
	var opacity := SettingsPanel.slider(content, "SETTINGS_TOUCH_OPACITY", "touch_opacity", Tuning.TOUCH_OPACITY_RANGE.x, Tuning.TOUCH_OPACITY_RANGE.y)
	opacity.value_changed.connect(rebuild)
	var toggles := SettingsPanel.toggles(content, {"touch_left": "SETTINGS_TOUCH_LEFT", "touch_haptics": "SETTINGS_TOUCH_HAPTIC"})
	for t in toggles:
		t.toggled.connect(rebuild)
	var back := Ui.button("SETTINGS_BACK", "AccentButton")
	content.add_child(back)
	back.pressed.connect(close)
	Ui.focus_chain.call_deferred([size, opacity] + toggles + [back])
