class_name SafehouseMenu
extends Modal
## Trong nhà an toàn: nghỉ (đầy máu + lưu game), thuê đàn em, thay đồ. Kết quả: "rest" / "hire" / "outfit" / null.


func _build(content: VBoxContainer) -> void:
	content.custom_minimum_size.x = 420
	content.add_child(Ui.label("SAFEHOUSE_TITLE", "HeaderLabel"))
	var buttons := button_column(["SAFEHOUSE_REST", "SAFEHOUSE_HIRE", "SAFEHOUSE_OUTFIT", "SAFEHOUSE_LEAVE"], {"SAFEHOUSE_REST": "AccentButton"})
	buttons[1].auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	buttons[1].text = I18n.fmt("SAFEHOUSE_HIRE", {"price": I18n.money(Tuning.ALLY_PRICE)})
	buttons[0].pressed.connect(close.bind("rest"))
	buttons[1].pressed.connect(close.bind("hire"))
	buttons[2].pressed.connect(close.bind("outfit"))
	buttons[3].pressed.connect(close)
