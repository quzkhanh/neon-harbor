class_name ShopWidgets
extends Object
## Thành phần hiển thị của cửa hàng: dòng súng, thanh chỉ số, nhãn tiền.

const ICON := "res://assets/sprites/weapons/icon_%s.png"
const LOCK := "res://assets/sprites/ui/icon_lock.png"
const ROW_HEIGHT := 62
# Mốc chuẩn hoá chỉ số (giá trị đạt thanh đầy)
const STAT_MAX := {"damage": 200.0, "rate": 15.0, "accuracy": 20.0, "mag": 100.0}


static func money_label() -> Label:
	var l := Ui.label("", "MoneyLabel")
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var refresh := func(_v: Variant = null) -> void: l.text = I18n.money(Game.money)
	refresh.call()
	Game.money_changed.connect(refresh)
	l.tree_exiting.connect(func() -> void: Game.money_changed.disconnect(refresh))
	return l


static func weapon_row(w: Dictionary) -> Button:
	var b := Ui.button("")
	b.custom_minimum_size.y = ROW_HEIGHT
	var row := Ui.hbox(12)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -14
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var well := PanelContainer.new()
	well.theme_type_variation = "IconWell"
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(Ui.texture(ICON % w.id, Vector2(72, 36)))
	row.add_child(well)
	var name_label := Ui.label(w.name, "", HORIZONTAL_ALIGNMENT_LEFT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	var status := Ui.label("", "SmallLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	status.name = "Status"
	status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(status)
	var lock := Ui.texture(LOCK, Vector2(26, 26))
	lock.name = "Lock"
	row.add_child(lock)
	return b


static func update_row(b: Button, id: String, selected: bool) -> void:
	var w := DataDB.weapon(id)
	var status: Label = b.find_child("Status", true, false)
	var lock: Control = b.find_child("Lock", true, false)
	var unlocked := Game.is_unlocked(id)
	lock.visible = not unlocked
	if Game.owned.has(id):
		status.text = b.tr("SHOP_OWNED")
		status.add_theme_color_override("font_color", Palette.CYAN)
	elif unlocked:
		status.text = I18n.money(Game.price(int(w.price)))
		status.add_theme_color_override("font_color", Palette.MONEY)
	else:
		status.text = ""
	b.modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.6)
	b.add_theme_stylebox_override("normal", b.get_theme_stylebox("hover") if selected else b.get_theme_stylebox("normal", "Button"))


static func stat_row(parent: Control, key: String) -> ProgressBar:
	var row := Ui.hbox(12)
	var l := Ui.label(key, "SmallLabel", HORIZONTAL_ALIGNMENT_LEFT)
	l.custom_minimum_size.x = 150
	row.add_child(l)
	var bar := ProgressBar.new()
	bar.theme_type_variation = "StatBar"
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size.y = 12
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	parent.add_child(row)
	return bar


static func stat_value(w: Dictionary, key: String) -> float:
	match key:
		"damage":
			return clampf(float(w.damage) * float(w.pellets) / STAT_MAX.damage, 0.05, 1.0)
		"rate":
			return clampf(float(w.rate) / STAT_MAX.rate, 0.05, 1.0)
		"accuracy":
			return clampf(1.0 - float(w.spread) / STAT_MAX.accuracy, 0.05, 1.0)
		_:
			return clampf(float(w.mag) / STAT_MAX.mag, 0.05, 1.0)
