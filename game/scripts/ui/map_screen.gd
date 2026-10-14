class_name MapScreen
extends Modal
## Bản đồ cả thành phố (phím M): vị trí, mục tiêu và đường GPS, cửa hàng, bệnh viện, tên các khu.

const MAX_SIZE := Vector2(1100, 520)

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
	var legend := Ui.hbox(22)
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	for entry in MapIcon.LEGEND:
		var row := Ui.hbox(8)
		row.add_child(LegendIcon.new(entry[0], entry[1]))
		row.add_child(Ui.label(entry[2], "SmallLabel"))
		legend.add_child(row)
	content.add_child(legend)
	var close_key := "MAP_CLOSE_TOUCH" if TouchControls.wanted() else "MAP_CLOSE"
	content.add_child(Ui.live_label(close_key, func() -> Dictionary: return {"key": InputSetup.key_label(&"map")}, "SmallLabel"))


## Điện thoại không có phím M hay Esc: chạm bất kỳ đâu để đóng (lớp mờ của Modal nuốt chạm nên phải bắt ở _input).
func _input(event: InputEvent) -> void:
	if TouchControls.wanted() and event is InputEventScreenTouch and event.pressed:
		get_viewport().set_input_as_handled()
		close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		close()
	else:
		super(event)


## Một biểu tượng trong hàng chú thích.
class LegendIcon extends Control:
	var kind: MapIcon.Kind
	var color: Color

	func _init(icon_kind: MapIcon.Kind, icon_color: Color) -> void:
		kind = icon_kind
		color = icon_color
		custom_minimum_size = Vector2.ONE * (MapIcon.RADIUS + 2.0) * 2.0
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		MapIcon.draw(self, size * 0.5, kind, color)
