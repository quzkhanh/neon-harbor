class_name MissionComplete
extends Modal
## Màn hoàn thành nhiệm vụ: tiền thưởng, súng mở bán, nút quảng cáo gấp đôi thưởng (rewarded).

const ICON := "res://assets/sprites/weapons/icon_%s.png"

var mission_id: int
var reward: int
var unlocked: Array
var _reward_label: Label
var _ad_button: Button


func _init(n: int, money: int, weapons: Array) -> void:
	super()
	mission_id = n
	reward = money
	unlocked = weapons


func _build(content: VBoxContainer) -> void:
	content.custom_minimum_size.x = 520
	var title := Ui.label("MISSION_COMPLETE", "HeaderLabel")
	title.add_theme_color_override("font_color", Palette.GOLD)
	content.add_child(title)
	content.add_child(Ui.label(Game.mission(mission_id).title, "SubLabel"))
	content.add_child(Ui.label("REWARD", "SmallLabel"))
	_reward_label = Ui.live_label("REWARD_AMOUNT", func() -> Dictionary: return {"money": I18n.money(reward)}, "MoneyLabel")
	_reward_label.add_theme_font_size_override("font_size", 44)
	content.add_child(_reward_label)
	for id in unlocked:
		var row := Ui.hbox(12)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var well := PanelContainer.new()
		well.theme_type_variation = "IconWell"
		well.add_child(Ui.texture(ICON % id, Vector2(96, 48)))
		row.add_child(well)
		var w := DataDB.weapon(id)
		row.add_child(Ui.live_label("UNLOCKED_WEAPON", func() -> Dictionary: return {"weapon": tr(w.name)}))
		content.add_child(row)
	_ad_button = Ui.button("AD_DOUBLE_REWARD", "AccentButton")
	_ad_button.add_to_group("ad_button")
	_ad_button.visible = Ads.rewarded_available("double_reward")
	_ad_button.pressed.connect(_double)
	content.add_child(_ad_button)
	var cont := Ui.button("CONTINUE")
	cont.pressed.connect(close)
	content.add_child(cont)
	Ui.focus_chain.call_deferred([_ad_button, cont])


func _double() -> void:
	_ad_button.disabled = true
	if await Ads.show_rewarded("double_reward"):
		Game.add_money(reward)
		reward *= 2
		_reward_label.refresh()
		Sfx.play("cash")
		_ad_button.text = "REWARD_DOUBLED"
	else:
		_ad_button.disabled = false
