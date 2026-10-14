class_name MapScreen
extends Modal
## Bản đồ cả thành phố (phím M): vị trí, mục tiêu và đường GPS, cửa hàng, bệnh viện, tên các khu.

const MAX_SIZE := Vector2(1100, 560)

var city: City


func _init(c: City) -> void:
	super()
	city = c


func _build(content: VBoxContainer) -> void:
	var cells := Vector2(city.data.size)
	var px := minf(MAX_SIZE.x / cells.x, MAX_SIZE.y / cells.y)
	var view := Minimap.new(city, cells * px, px, false)
	content.add_child(view)
	for d in DataDB.districts():
		var r: Array = d.rect
		var label := Ui.label(d.key, "WorldLabel")
		label.modulate.a = 0.8
		label.position = (Vector2(float(r[0]), float(r[1])) + Vector2(float(r[2]), float(r[3])) * 0.5) * px - Vector2(150, 14)
		label.size = Vector2(300, 28)
		view.add_child(label)
	content.add_child(Ui.live_label("MAP_CLOSE", func() -> Dictionary: return {"key": InputSetup.key_label(&"map")}, "SmallLabel"))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		close()
	else:
		super(event)
