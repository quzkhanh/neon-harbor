class_name Marker
extends Node2D
## Vòng tròn nhấp nháy đánh dấu điểm nhiệm vụ/đích đến, có thể kèm nhãn (khoá dịch).

const RADIUS := 34.0
const WIDTH := 5.0

var color := Palette.MARKER
var _time := 0.0
var _label: Label


static func make(parent: Node, pos: Vector2, marker_color: Color, label_key := "") -> Marker:
	var m := Marker.new()
	m.color = marker_color
	m.global_position = pos
	m.z_index = 3
	if label_key != "":
		m._label = Ui.label(label_key, "WorldLabel")
		m._label.position = Vector2(-150, -RADIUS - 44)
		m._label.size = Vector2(300, 30)
		m.add_child(m._label)
	parent.add_child(m)
	return m


func _ready() -> void:
	add_to_group("markers")
	var glow := Sprite2D.new()
	glow.texture = Fx.tex("glow")
	glow.material = Fx.additive()
	glow.modulate = Color(color, 0.5)
	glow.scale = Vector2.ONE * 1.1
	add_child(glow)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + 0.12 * sin(_time * 4.0)
	draw_circle(Vector2.ZERO, RADIUS * pulse, Color(color, 0.18))
	draw_arc(Vector2.ZERO, RADIUS * pulse, 0.0, TAU, 48, color, WIDTH, true)
	var bob := sin(_time * 3.0) * 5.0
	var tip := Vector2(0, -RADIUS - 8 + bob)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-11, -16), tip + Vector2(11, -16)]), color)
