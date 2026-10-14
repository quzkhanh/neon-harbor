class_name Crosswalks
extends Node2D
## Vẽ vạch kẻ qua đường (sọc trắng song song chiều xe chạy) lên các ô "=".

const STRIPES := 4
const STRIPE_WIDTH := 8.0
const STRIPE_INSET := 6.0
const COLOR := Color(0.93, 0.93, 0.9, 0.9)

var _cells: Array[Vector2i] = []
var _vertical := {}


func _init(map: MapData) -> void:
	z_index = -19
	_cells = map.find_all("=")
	for c in _cells:
		_vertical[c] = map.is_road(c + Vector2i.UP) and map.is_road(c + Vector2i.DOWN)


func _draw() -> void:
	var t := float(Tuning.TILE)
	var step := t / STRIPES
	for c in _cells:
		var origin := Vector2(c) * t
		for i in STRIPES:
			var offset := step * i + (step - STRIPE_WIDTH) / 2.0
			var r := Rect2(origin + Vector2(offset, STRIPE_INSET), Vector2(STRIPE_WIDTH, t - STRIPE_INSET * 2))
			if not _vertical[c]:
				r = Rect2(origin + Vector2(STRIPE_INSET, offset), Vector2(t - STRIPE_INSET * 2, STRIPE_WIDTH))
			draw_rect(r, COLOR)
