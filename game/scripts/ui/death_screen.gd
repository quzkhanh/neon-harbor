class_name DeathScreen
extends Modal
## Màn chết: về bệnh viện (mất 10% tiền, mất sao) hoặc hồi sinh tại chỗ bằng quảng cáo revive_here.
## Kết quả: true nếu hồi sinh tại chỗ.


func _init() -> void:
	super()
	cancellable = false


func _build(content: VBoxContainer) -> void:
	content.custom_minimum_size.x = 460
	var title := Ui.label("DEATH_TITLE", "TitleLabel")
	title.add_theme_color_override("font_color", Palette.HEALTH)
	content.add_child(title)
	var fee := int(Game.money * Tuning.DEATH_FEE)
	content.add_child(Ui.live_label("DEATH_FEE", func() -> Dictionary: return {"fee": I18n.money(fee)}, "SubLabel"))
	var revive := Ui.button("AD_REVIVE_HERE", "AccentButton")
	revive.add_to_group("ad_button")
	revive.visible = Ads.rewarded_available("revive_here")
	content.add_child(revive)
	var hospital := Ui.button("DEATH_HOSPITAL")
	content.add_child(hospital)
	revive.pressed.connect(_revive.bind(revive))
	hospital.pressed.connect(close.bind(false))
	Ui.focus_chain.call_deferred([revive, hospital])


func _revive(button: Button) -> void:
	button.disabled = true
	if await Ads.show_rewarded("revive_here"):
		close(true)
	else:
		button.disabled = false
