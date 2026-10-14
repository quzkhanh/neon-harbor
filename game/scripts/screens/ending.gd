extends Node2D
## Màn kết sau NV3: đoạn kết ngắn, rồi chơi tự do tiếp hoặc về menu.


func _ready() -> void:
	add_child(Backdrop.new())
	var modal := Modal.new()
	modal.cancellable = false
	add_child(modal)
	var box := modal.box
	box.custom_minimum_size.x = 640
	var title := Ui.label("ENDING_TITLE", "TitleLabel")
	title.add_theme_color_override("font_color", Palette.GOLD)
	box.add_child(title)
	var text := Ui.label("ENDING_TEXT", "SubLabel")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	box.add_child(Ui.live_label("ENDING_MONEY", func() -> Dictionary: return {"money": I18n.money(Game.money)}, "MoneyLabel"))
	var buttons := modal.button_column(["ENDING_FREE_ROAM", "PAUSE_TO_MENU"], {"ENDING_FREE_ROAM": "AccentButton"})
	buttons[0].pressed.connect(Game.go.bind(Game.CITY_SCENE))
	buttons[1].pressed.connect(Game.go.bind(Game.MENU_SCENE))
	Music.play()
