extends Modal
## Cửa hàng súng: danh sách có icon, chỉ số dạng thanh để so sánh, giá, mua súng/đạn,
## giáp, hộp máu, đạn miễn phí qua quảng cáo. Súng chưa mở khoá hiện ổ khoá kèm điều kiện.

const ICON := "res://assets/sprites/weapons/icon_%s.png"
const STATS := [["SHOP_STAT_DAMAGE", "damage"], ["SHOP_STAT_RATE", "rate"], ["SHOP_STAT_ACCURACY", "accuracy"], ["SHOP_STAT_MAG", "mag"]]

var selected := ""
var _rows := {}
var _detail_icon: TextureRect
var _detail_name: Label
var _bars := {}
var _info: LiveLabel
var _buy: Button
var _buy_ammo: Button
var _armor: Button
var _medkit: Button
var _free_ammo: Button
var _status: Label


func _build(content: VBoxContainer) -> void:
	content.custom_minimum_size = Vector2(1000, 0)
	var header := Ui.hbox(16)
	content.add_child(header)
	var title := Ui.label("SHOP_TITLE", "HeaderLabel", HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(ShopWidgets.money_label())
	var close_btn := Ui.button("SHOP_CLOSE", "FlatButton")
	close_btn.pressed.connect(close)
	header.add_child(close_btn)
	var body := Ui.hbox(20)
	content.add_child(body)
	body.add_child(_build_list())
	body.add_child(_build_detail())
	var footer := Ui.hbox(12)
	content.add_child(footer)
	_armor = _footer_button(footer, _buy_armor)
	_medkit = _footer_button(footer, _buy_medkit)
	_free_ammo = _footer_button(footer, _watch_free_ammo, "AccentButton")
	_free_ammo.add_to_group("ad_button")
	_status = Ui.label("", "SmallLabel")
	_status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	content.add_child(_status)
	Game.notice.connect(_on_notice)
	Game.weapons_changed.connect(_refresh)
	Game.money_changed.connect(func(_m: int) -> void: _refresh())
	_select(Game.current)
	_rows[Game.current].grab_focus.call_deferred()


func _build_list() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := Ui.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for w in DataDB.weapons():
		var row := ShopWidgets.weapon_row(w)
		row.pressed.connect(_select.bind(w.id))
		row.focus_entered.connect(_select.bind(w.id))
		list.add_child(row)
		_rows[w.id] = row
	return scroll


func _build_detail() -> Control:
	var col := Ui.vbox(10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var well := PanelContainer.new()
	well.theme_type_variation = "IconWell"
	_detail_icon = Ui.texture("", Vector2(240, 120))
	well.add_child(_detail_icon)
	col.add_child(well)
	_detail_name = Ui.label("", "HeaderLabel", HORIZONTAL_ALIGNMENT_LEFT)
	col.add_child(_detail_name)
	for stat in STATS:
		_bars[stat[1]] = ShopWidgets.stat_row(col, stat[0])
	_info = Ui.live_label("", _info_params, "SubLabel", HORIZONTAL_ALIGNMENT_LEFT)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_info)
	var buttons := Ui.hbox(12)
	col.add_child(buttons)
	_buy = _footer_button(buttons, func() -> void: _purchase(Game.buy_weapon(selected)), "AccentButton")
	_buy_ammo = _footer_button(buttons, func() -> void: _purchase(Game.buy_ammo(selected)))
	return col


func _footer_button(parent: Control, action: Callable, variation := "") -> Button:
	var b := Ui.button("", variation)
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _select(id: String) -> void:
	selected = id
	_refresh()


func _refresh() -> void:
	var w := DataDB.weapon(selected)
	for id in _rows:
		ShopWidgets.update_row(_rows[id], id, id == selected)
	_detail_icon.texture = load(ICON % selected)
	_detail_name.text = w.name
	for key in _bars:
		_bars[key].value = ShopWidgets.stat_value(w, key)
	var owned := Game.owned.has(selected)
	var unlocked := Game.is_unlocked(selected)
	_info.setup("SHOP_LOCKED" if not unlocked else ("SHOP_AMMO_OWNED" if owned else "SHOP_NOT_OWNED"))
	_buy.visible = unlocked and not owned
	_buy.text = I18n.fmt("SHOP_BUY", {"price": I18n.money(int(w.price))})
	_buy_ammo.visible = owned and int(w.reserve_max) >= 0
	_buy_ammo.disabled = Game.ammo_full(selected)
	_buy_ammo.text = I18n.fmt("SHOP_BUY_AMMO", {"amount": int(w.ammo_pack), "price": I18n.money(int(w.ammo_price))})
	_armor.text = I18n.fmt("SHOP_ARMOR", {"price": I18n.money(Tuning.ARMOR_PRICE)})
	_armor.disabled = Game.armor >= Tuning.MAX_ARMOR
	_medkit.text = I18n.fmt("SHOP_MEDKIT", {"price": I18n.money(Tuning.MEDKIT_PRICE)})
	_medkit.disabled = Game.health >= Tuning.MAX_HEALTH
	_free_ammo.text = tr("AD_FREE_AMMO")
	_free_ammo.visible = Ads.rewarded_available("free_ammo")


func _info_params() -> Dictionary:
	var w := DataDB.weapon(selected)
	var a := Game.ammo(selected)
	var reserve: String = tr("AMMO_INFINITE") if int(a.reserve) < 0 else str(int(a.reserve))
	return {"mission": int(w.unlock), "mag": int(a.mag), "reserve": reserve}


func _purchase(ok: bool) -> void:
	if ok:
		Sfx.play("cash")
		_status.text = tr("SHOP_BOUGHT")
	_refresh()


func _buy_armor() -> void:
	if Game.spend(Tuning.ARMOR_PRICE):
		Game.add_armor(Tuning.MAX_ARMOR)
		Game.save_game()
		_purchase(true)


func _buy_medkit() -> void:
	if Game.spend(Tuning.MEDKIT_PRICE):
		Game.heal(Tuning.MAX_HEALTH)
		Game.save_game()
		_purchase(true)


func _watch_free_ammo() -> void:
	_free_ammo.disabled = true
	if await Ads.show_rewarded("free_ammo"):
		for id in Game.owned:
			Game.give_ammo(id)
		Game.save_game()
		Sfx.play("pickup")
		_status.text = tr("SHOP_FREE_AMMO_DONE")
	_free_ammo.disabled = false
	_refresh()


func _on_notice(text: String) -> void:
	_status.text = text
