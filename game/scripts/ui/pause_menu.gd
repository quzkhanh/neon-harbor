class_name PauseMenu
extends Modal
## Tạm dừng: Tiếp tục / Phím tắt / Cài đặt / Thống kê / Về menu.


func _build(content: VBoxContainer) -> void:
	content.custom_minimum_size.x = 380
	content.add_child(Ui.label("PAUSE_TITLE", "HeaderLabel"))
	var buttons := button_column(["PAUSE_RESUME", "PAUSE_HELP", "MENU_SETTINGS", "PAUSE_STATS", "PAUSE_TO_MENU"], {"PAUSE_RESUME": "AccentButton"})
	buttons[0].pressed.connect(close)
	buttons[1].pressed.connect(close.bind("help"))
	buttons[2].pressed.connect(close.bind("settings"))
	buttons[3].pressed.connect(close.bind("stats"))
	buttons[4].pressed.connect(close.bind("menu"))
