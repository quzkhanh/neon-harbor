class_name Critters
extends Node
## Giữ vài con thú vật quanh camera (xem Critter): sinh ngoài khung hình, xoá khi đi quá xa.
## Bồ câu, mèo, chó ở vỉa hè và cỏ; hải âu bay trên mặt nước; cua ở mép nước.

const TICK := 1.5
const MAX := {"pigeon": 8, "cat": 3, "dog": 3, "gull": 5, "crab": 4}

var city: City
var _timer := 0.0
var _cells := {}


func _init(c: City) -> void:
	city = c
	name = "Critters"


func _ready() -> void:
	var land: Array[Vector2i] = []
	for ch in ",\"":
		land.append_array(city.data.find_all(ch))
	var water := city.data.find_all("~")
	_cells = {"pigeon": land, "cat": land, "dog": land, "gull": water, "crab": _shore()}
	for kind in MAX:
		for i in MAX[kind]:
			_spawn(kind, true)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = TICK
		_despawn()
		for kind in MAX:
			if _count(kind) < MAX[kind]:
				_spawn(kind, false)


func _spawn(kind: String, initial: bool) -> void:
	var cells: Array[Vector2i] = _cells[kind]
	if cells.is_empty():
		return
	var cell := city.population.pick_cell(cells, initial)
	if cell.x < 0:
		return
	var c := Critter.new()
	c.kind = kind
	c.city = city
	c.global_position = MapData.cell_center(cell)
	city.actors.add_child(c)


func _count(kind: String) -> int:
	return get_tree().get_nodes_in_group("critters").filter(func(c: Critter) -> bool: return c.kind == kind).size()


func _despawn() -> void:
	var center := city.camera.get_screen_center_position()
	var view := city.view_rect().grow(Tuning.TILE)
	for c in get_tree().get_nodes_in_group("critters"):
		if c.global_position.distance_to(center) > Tuning.DESPAWN_DIST and not view.has_point(c.global_position):
			c.queue_free()


## Ô đi được có nước kề bên (chỗ cua bò).
func _shore() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in city.data.find_all("~"):
		for d in MapData.DIRS:
			if city.data.is_ped_walkable(cell + d):
				out.append(cell + d)
	return out
