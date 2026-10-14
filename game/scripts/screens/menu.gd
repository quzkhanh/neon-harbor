extends Node2D
## Menu chính: tên game, Chơi tiếp / Chơi mới, Toàn màn hình (chỉ Web cảm ứng), Cài đặt, Thoát (ẩn trên Web).
## Điều khiển được bằng phím và tay cầm.

var _ui: CanvasLayer
var _buttons: Array = []


func _ready() -> void:
	add_child(Backdrop.new())
	_ui = CanvasLayer.new()
	add_child(_ui)
	_ui.add_child(_shade())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 96)
	margin.add_theme_constant_override("margin_bottom", 40)
	_ui.add_child(margin)
	var col := Ui.vbox(14)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	margin.add_child(col)
	var title := Ui.label("GAME_TITLE", "TitleLabel", HORIZONTAL_ALIGNMENT_LEFT)
	title.add_theme_color_override("font_color", Palette.ACCENT)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Palette.BG)
	title.add_theme_color_override("font_shadow_color", Color(Palette.ACCENT, 0.45))
	title.add_theme_constant_override("shadow_outline_size", 28)
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	col.add_child(title)
	var tagline := Ui.label("MENU_TAGLINE", "SubLabel", HORIZONTAL_ALIGNMENT_LEFT)
	col.add_child(tagline)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 24
	col.add_child(spacer)
	var keys := ["MENU_CONTINUE", "MENU_NEW_GAME", "MENU_FULLSCREEN", "MENU_SETTINGS", "MENU_QUIT"]
	for key in keys:
		var b := Ui.button(key, "AccentButton" if key == "MENU_CONTINUE" or (key == "MENU_NEW_GAME" and not Game.has_progress()) else "")
		b.custom_minimum_size.x = 320
		col.add_child(b)
		_buttons.append(b)
	_buttons[0].visible = Game.has_progress()
	_buttons[2].visible = OS.has_feature("web") and TouchControls.wanted() and JavaScriptBridge.eval("document.fullscreenEnabled ? 1 : 0") == 1
	_buttons[4].visible = not OS.has_feature("web")
	_buttons[0].pressed.connect(Game.continue_game)
	_buttons[1].pressed.connect(_new_game)
	_buttons[2].pressed.connect(_fullscreen)
	_buttons[3].pressed.connect(_settings)
	_buttons[4].pressed.connect(Game.quit)
	var credits := Ui.label("MENU_CREDITS", "SmallLabel", HORIZONTAL_ALIGNMENT_LEFT)
	credits.size_flags_vertical = Control.SIZE_SHRINK_END
	margin.add_child(credits)
	Ui.focus_chain(_buttons)
	Music.play()


## Dải tối bên trái để chữ menu dễ đọc trên nền bản đồ.
func _shade() -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(Palette.BG, 0.94))
	g.set_color(1, Color(Palette.BG, 0.0))
	g.set_offset(0, 0.35)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	var rect := TextureRect.new()
	rect.texture = tex
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.anchor_right = 0.75
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	return rect


## Toàn màn hình ẩn thanh trình duyệt; Android Chrome còn khoá được chiều ngang. Chỉ khoá được khi đã vào toàn màn hình
## (vào là bất đồng bộ) nên khoá trong sự kiện fullscreenchange. iPhone không có Fullscreen API: nút bị ẩn.
func _fullscreen() -> void:
	JavaScriptBridge.eval("document.addEventListener('fullscreenchange', () => { if (document.fullscreenElement && screen.orientation && screen.orientation.lock) screen.orientation.lock('landscape').catch(() => {}) }, { once: true })")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _new_game() -> void:
	if Game.has_progress():
		var modal := ConfirmModal.new("MENU_CONFIRM_NEW")
		add_child(modal)
		if not await modal.closed:
			Ui.focus_chain(_buttons)
			return
	Game.new_game()


func _settings() -> void:
	var modal := SettingsPanel.new()
	add_child(modal)
	await modal.closed
	Ui.focus_chain(_buttons)
