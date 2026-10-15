class_name DeathScreen
extends Modal
## Màn chết. Kết quả (Revive): làm lại nhiệm vụ vừa thất bại (miễn phí, chỉ khi chết giữa nhiệm vụ),
## về nhà an toàn gần nhất (miễn phí, xoá truy nã, chỉ khi đã mua nhà), hồi sinh tại chỗ (trả phí, giữ sao),
## ngồi tù (miễn phí, chờ JAIL_SECONDS giây, xoá truy nã, chỉ khi đang bị truy nã),
## hoặc về bệnh viện gần nhất (mất 10% tiền, mất sao).

enum Revive { HOSPITAL, HERE, RETRY, SAFEHOUSE, JAIL }

var _retry: bool
var _home: bool


func _init(can_retry: bool, has_home := false) -> void:
	super()
	cancellable = false
	_retry = can_retry
	_home = has_home


func _build(content: VBoxContainer) -> void:
	content.custom_minimum_size.x = 480
	var title := Ui.label("DEATH_TITLE", "TitleLabel")
	title.add_theme_color_override("font_color", Palette.HEALTH)
	content.add_child(title)
	var here := _fee_button("DEATH_REVIVE_HERE", Tuning.REVIVE_HERE_FEE, Revive.HERE, "AccentButton")
	var retry := Ui.button("DEATH_RETRY", "AccentButton")
	retry.visible = _retry
	retry.pressed.connect(close.bind(Revive.RETRY))
	var home := Ui.button("DEATH_SAFEHOUSE", "AccentButton")
	home.visible = _home
	home.pressed.connect(close.bind(Revive.SAFEHOUSE))
	var jail := Ui.button("DEATH_JAIL")
	jail.visible = Game.stars > 0
	jail.pressed.connect(close.bind(Revive.JAIL))
	var hospital := _fee_button("DEATH_HOSPITAL", Tuning.DEATH_FEE, Revive.HOSPITAL)
	for b in [retry, home, here, jail, hospital]:
		content.add_child(b)
	content.add_child(Ui.label("DEATH_WANTED_NOTE", "SmallLabel"))
	Ui.focus_chain.call_deferred([retry, home, here, jail, hospital])


## Nút có phí kèm theo; màn chết không đổi ngôn ngữ khi đang mở nên dịch một lần là đủ.
func _fee_button(key: String, rate: float, result: Revive, variation := "") -> Button:
	var b := Ui.button("", variation)
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.text = I18n.fmt(key, {"fee": I18n.money(int(Game.money * rate * Game.discount()))})
	b.pressed.connect(close.bind(result))
	return b
