class_name HelpPanel
extends Modal
## Hướng dẫn (từ menu chính và menu tạm dừng): trang phím tắt và trang cách chơi (hồi máu, cắt đuôi cảnh sát...).

const SIZE := Vector2(780, 400)
const KEY_COLUMN := 230
## [khoá dịch của phím, khoá dịch của việc]
const KEYBOARD_ROWS := [
	["HELP_KEY_MOVE", "HELP_DO_MOVE"], ["HELP_KEY_AIM", "HELP_DO_AIM"], ["HELP_KEY_RELOAD", "HELP_DO_RELOAD"],
	["HELP_KEY_SWAP", "HELP_DO_SWAP"], ["HELP_KEY_SLOTS", "HELP_DO_SLOTS"], ["HELP_KEY_INTERACT", "HELP_DO_INTERACT"],
	["HELP_KEY_NITRO", "HELP_DO_NITRO"], ["HELP_KEY_HANDBRAKE", "HELP_DO_HANDBRAKE"], ["HELP_KEY_HORN", "HELP_DO_HORN"],
	["HELP_KEY_MAP", "HELP_DO_MAP"], ["HELP_KEY_PAUSE", "HELP_DO_PAUSE"],
]
const TOUCH_ROWS := [
	["HELP_TOUCH_LEFT", "HELP_DO_MOVE"], ["HELP_TOUCH_RIGHT", "HELP_DO_AIM_TOUCH"], ["TOUCH_INTERACT", "HELP_DO_INTERACT"],
	["TOUCH_RELOAD", "HELP_DO_RELOAD"], ["TOUCH_SWAP", "HELP_DO_SWAP_TOUCH"], ["TOUCH_NITRO", "HELP_DO_NITRO"],
	["TOUCH_MAP", "HELP_DO_MAP"], ["TOUCH_PAUSE", "HELP_DO_PAUSE"],
]
## [tiêu đề, nội dung]
const TIPS := [
	["HELP_TIP_HEAL", "HELP_TIP_HEAL_BODY"], ["HELP_TIP_COPS", "HELP_TIP_COPS_BODY"],
	["HELP_TIP_AVOID", "HELP_TIP_AVOID_BODY"], ["HELP_TIP_MONEY", "HELP_TIP_MONEY_BODY"],
	["HELP_TIP_CARS", "HELP_TIP_CARS_BODY"], ["HELP_TIP_BADGE", "HELP_TIP_BADGE_BODY"], ["HELP_TIP_WATER", "HELP_TIP_WATER_BODY"],
]

var _pages: Array[Control] = []
var _tabs: Array[Button] = []


func _build(content: VBoxContainer) -> void:
	content.custom_minimum_size.x = SIZE.x
	content.add_child(Ui.label("HELP_TITLE", "HeaderLabel"))
	var tab_row := Ui.hbox(12)
	content.add_child(tab_row)
	var group := ButtonGroup.new()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var stack := Ui.vbox(0)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)
	for tab in [["HELP_TAB_KEYS", _controls_page()], ["HELP_TAB_BASICS", _tips_page()]]:
		var b := Ui.button(tab[0])
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_show.bind(_tabs.size()))
		tab_row.add_child(b)
		_tabs.append(b)
		stack.add_child(tab[1])
		_pages.append(tab[1])
	var back := Ui.button("HELP_CLOSE", "AccentButton")
	content.add_child(back)
	back.pressed.connect(close)
	Ui.focus_chain([_tabs[0], _tabs[1], back])
	_show(0)


func _show(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index
		_tabs[i].button_pressed = i == index


func _controls_page() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for row in TOUCH_ROWS if TouchControls.wanted() else KEYBOARD_ROWS:
		var key := Ui.label(row[0], "SubLabel", HORIZONTAL_ALIGNMENT_LEFT)
		key.custom_minimum_size.x = KEY_COLUMN
		key.add_theme_color_override("font_color", Palette.ACCENT)
		grid.add_child(key)
		grid.add_child(_wrapped(row[1], "SmallLabel"))
	return grid


func _tips_page() -> Control:
	var list := Ui.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for tip in TIPS:
		var title := Ui.label(tip[0], "SubLabel", HORIZONTAL_ALIGNMENT_LEFT)
		title.add_theme_color_override("font_color", Palette.ACCENT)
		list.add_child(title)
		list.add_child(_wrapped(tip[1], "SmallLabel"))
	return list


func _wrapped(key: String, variation: String) -> Label:
	var l := Ui.label(key, variation, HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
