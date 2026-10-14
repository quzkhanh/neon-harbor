class_name UiTheme
extends Object
## Theme toàn cục dựng bằng code: font có chuỗi dự phòng, nút, panel, thanh trượt, thanh tiến độ.

const FONT_DIR := "res://assets/fonts/"
const FALLBACKS := ["NotoSans-Regular.ttf", "NotoSansMath-Symbols.ttf"]
const BASE_SIZE := 20
const RADIUS := 12
const GRABBER_SIZE := 22

static var _fonts := {}


## Font Be Vietnam Pro theo độ đậm, luôn kèm Noto Sans và Noto Sans Math (ký hiệu) làm font dự phòng.
static func font(weight := "SemiBold") -> FontFile:
	if not _fonts.has(weight):
		var f: FontFile = load(FONT_DIR + "BeVietnamPro-%s.ttf" % weight).duplicate()
		f.fallbacks = FALLBACKS.map(func(n: String) -> Font: return load(FONT_DIR + n))
		_fonts[weight] = f
	return _fonts[weight]


## Gộp vào theme mặc định của engine để mọi Control (kể cả dưới CanvasLayer) đều nhận.
static func install() -> void:
	ThemeDB.fallback_font = font()
	ThemeDB.fallback_font_size = BASE_SIZE
	ThemeDB.get_default_theme().merge_with(build())


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = BASE_SIZE
	_buttons(t)
	_labels(t)
	_panels(t)
	_sliders(t)
	_bars(t)
	return t


static func box(color: Color, radius := RADIUS, border := 0, border_color := Palette.BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.anti_aliasing = true
	return s


static func _pad(s: StyleBox, h: float, v: float) -> StyleBox:
	s.content_margin_left = h
	s.content_margin_right = h
	s.content_margin_top = v
	s.content_margin_bottom = v
	return s


static func _buttons(t: Theme) -> void:
	var normal := _pad(box(Palette.PANEL_LIGHT, RADIUS, 2, Palette.BORDER), 24, 12)
	var hover := _pad(box(Palette.PANEL_HOVER, RADIUS, 2, Palette.ACCENT), 24, 12)
	var pressed := _pad(box(Palette.ACCENT_DARK, RADIUS, 2, Palette.ACCENT), 24, 12)
	var disabled := _pad(box(Palette.PANEL_LIGHT.darkened(0.3), RADIUS, 2, Palette.BORDER.darkened(0.3)), 24, 12)
	var focus := box(Color.TRANSPARENT, RADIUS + 2, 3, Palette.ACCENT)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	for type in ["Button"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, focus)
		t.set_color("font_color", type, Palette.TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, Color.WHITE)
		t.set_color("font_focus_color", type, Color.WHITE)
		t.set_color("font_disabled_color", type, Palette.TEXT_MUTED)
		t.set_font_size("font_size", type, 22)
	t.set_type_variation("AccentButton", "Button")
	t.set_stylebox("normal", "AccentButton", _pad(box(Palette.ACCENT, RADIUS, 2, Palette.ACCENT), 24, 12))
	t.set_stylebox("hover", "AccentButton", _pad(box(Palette.ACCENT.lightened(0.12), RADIUS, 2, Color.WHITE), 24, 12))
	t.set_type_variation("FlatButton", "Button")
	t.set_stylebox("normal", "FlatButton", _pad(box(Color.TRANSPARENT, RADIUS, 2, Color.TRANSPARENT), 14, 8))
	t.set_stylebox("hover", "FlatButton", _pad(box(Palette.PANEL_HOVER, RADIUS, 2, Palette.BORDER), 14, 8))
	t.set_stylebox("pressed", "FlatButton", _pad(box(Palette.PANEL_HOVER, RADIUS, 2, Palette.ACCENT), 14, 8))


static func _labels(t: Theme) -> void:
	t.set_color("font_color", "Label", Palette.TEXT)
	_label_variant(t, "TitleLabel", "ExtraBold", 84, Palette.TEXT, 0)
	_label_variant(t, "HeaderLabel", "Bold", 34, Palette.TEXT, 0)
	_label_variant(t, "SubLabel", "Regular", 20, Palette.TEXT_DIM, 0)
	_label_variant(t, "SmallLabel", "Regular", 16, Palette.TEXT_DIM, 0)
	_label_variant(t, "MoneyLabel", "ExtraBold", 28, Palette.MONEY, 6)
	_label_variant(t, "HudLabel", "Bold", 22, Palette.TEXT, 6)
	_label_variant(t, "HintLabel", "SemiBold", 20, Palette.TEXT, 6)
	_label_variant(t, "WorldLabel", "ExtraBold", 22, Palette.TEXT, 8)
	_label_variant(t, "BannerLabel", "ExtraBold", 44, Palette.TEXT, 10)


static func _label_variant(t: Theme, name: String, weight: String, size: int, color: Color, outline: int) -> void:
	t.set_type_variation(name, "Label")
	t.set_font(&"font", name, font(weight))
	t.set_font_size(&"font_size", name, size)
	t.set_color(&"font_color", name, color)
	if outline > 0:
		t.set_constant(&"outline_size", name, outline)
		t.set_color(&"font_outline_color", name, Palette.OUTLINE)


static func _panels(t: Theme) -> void:
	var panel := _pad(box(Palette.PANEL, 16, 1, Palette.BORDER), 28, 24)
	panel.shadow_color = Palette.SHADOW
	panel.shadow_size = 18
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_type_variation("HudPanel", "PanelContainer")
	t.set_stylebox("panel", "HudPanel", _pad(box(Palette.PANEL_SOFT, 12, 1, Palette.BORDER), 14, 10))
	t.set_type_variation("CardPanel", "PanelContainer")
	t.set_stylebox("panel", "CardPanel", _pad(box(Palette.PANEL_LIGHT, 12, 1, Palette.BORDER), 16, 12))
	t.set_type_variation("IconWell", "PanelContainer")
	t.set_stylebox("panel", "IconWell", _pad(box(Palette.ICON_WELL, 10, 2, Palette.ICON_WELL.lightened(0.25)), 6, 2))


static func _sliders(t: Theme) -> void:
	var track := box(Palette.PANEL_LIGHT, 6, 1, Palette.BORDER)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", box(Palette.ACCENT, 6))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(Palette.ACCENT.lightened(0.15), 6))
	t.set_icon("grabber", "HSlider", _circle(GRABBER_SIZE, Color.WHITE))
	t.set_icon("grabber_highlight", "HSlider", _circle(GRABBER_SIZE, Palette.CYAN))
	var focus := box(Color.TRANSPARENT, 10, 2, Palette.ACCENT)
	focus.expand_margin_left = 6
	focus.expand_margin_right = 6
	focus.expand_margin_top = 4
	focus.expand_margin_bottom = 4
	t.set_stylebox("focus", "HSlider", focus)


static func _bars(t: Theme) -> void:
	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.45), 5))
	t.set_stylebox("fill", "ProgressBar", box(Palette.CYAN, 5))
	t.set_constant("outline_size", "ProgressBar", 0)
	for v in [["HealthBar", Palette.HEALTH], ["ArmorBar", Palette.ARMOR], ["StatBar", Palette.CYAN]]:
		t.set_type_variation(v[0], "ProgressBar")
		t.set_stylebox("fill", v[0], box(v[1], 5))


static func _circle(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			img.set_pixel(x, y, Color(color, clampf(r - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
