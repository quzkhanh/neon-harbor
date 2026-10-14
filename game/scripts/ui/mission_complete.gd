class_name MissionComplete
extends Modal
## Màn hoàn thành nhiệm vụ: tiền thưởng, súng mở bán.

const ICON := "res://assets/sprites/weapons/icon_%s.png"

var mission_id: int
var reward: int
var unlocked: Array


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
	var reward_label := Ui.live_label("REWARD_AMOUNT", func() -> Dictionary: return {"money": I18n.money(reward)}, "MoneyLabel")
	reward_label.add_theme_font_size_override("font_size", 44)
	content.add_child(reward_label)
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
	var cont := Ui.button("CONTINUE", "AccentButton")
	cont.pressed.connect(close)
	content.add_child(cont)
	Ui.focus_chain.call_deferred([cont])
