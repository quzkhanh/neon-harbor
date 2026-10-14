class_name MapData
extends RefCounted
## Bản đồ ASCII: đọc file, tra loại ô, hướng làn, toạ độ ô <-> thế giới.

const SOLID := "#Tx~"
const LANES := {"<": Vector2i.LEFT, ">": Vector2i.RIGHT, "^": Vector2i.UP, "v": Vector2i.DOWN}
const ROAD := "<>^v+="
const PED_WALK := ",=_-PSHG123d"
const FLOORS := ",\".~_-<>^v+="
const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var size := Vector2i.ZERO
var _rows: PackedStringArray


static func load_file(path: String) -> MapData:
	var map := MapData.new()
	var text := FileAccess.get_file_as_string(path)
	for line in text.split("\n"):
		if line.strip_edges() != "":
			map._rows.append(line)
	map.size = Vector2i(map._rows[0].length(), map._rows.size())
	return map


func at(cell: Vector2i) -> String:
	if not in_bounds(cell):
		return "#"
	return _rows[cell.y][cell.x]


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func is_solid(cell: Vector2i) -> bool:
	return SOLID.contains(at(cell))


func is_road(cell: Vector2i) -> bool:
	return ROAD.contains(at(cell))


func is_ped_walkable(cell: Vector2i) -> bool:
	return PED_WALK.contains(at(cell))


func lane_dir(cell: Vector2i) -> Vector2i:
	return LANES.get(at(cell), Vector2i.ZERO)


## Mặt nền dưới các ô đặc biệt (P, S, c...): loại nền phổ biến nhất trong 4 ô kề.
func floor_of(cell: Vector2i) -> String:
	var ch := at(cell)
	if FLOORS.contains(ch):
		return ch
	var counts := {}
	for d in DIRS:
		var n := at(cell + d)
		if FLOORS.contains(n) and n != "~" and not is_road(cell + d):
			counts[n] = counts.get(n, 0) + 1
	var best := ","
	for k in counts:
		if counts[k] > counts.get(best, 0):
			best = k
	return best


func find_all(ch: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in size.y:
		var x := _rows[y].find(ch)
		while x != -1:
			out.append(Vector2i(x, y))
			x = _rows[y].find(ch, x + 1)
	return out


func find(ch: String) -> Vector2i:
	var all := find_all(ch)
	return all[0] if all.size() > 0 else Vector2i(-1, -1)


static func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * Tuning.TILE


static func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / Tuning.TILE), floori(pos.y / Tuning.TILE))


func world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size) * Tuning.TILE)
