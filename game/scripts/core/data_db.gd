class_name DataDB
extends Object
## Bảng súng và xe đọc từ data/*.json (thêm súng/xe = thêm dữ liệu).

const WEAPONS_PATH := "res://data/weapons.json"
const VEHICLES_PATH := "res://data/vehicles.json"

static var _weapons: Array = []
static var _vehicles: Dictionary = {}


static func weapons() -> Array:
	if _weapons.is_empty():
		_weapons = JSON.parse_string(FileAccess.get_file_as_string(WEAPONS_PATH))
	return _weapons


static func weapon(id: String) -> Dictionary:
	for w in weapons():
		if w.id == id:
			return w
	return {}


static func vehicle(kind: String) -> Dictionary:
	if _vehicles.is_empty():
		_vehicles = JSON.parse_string(FileAccess.get_file_as_string(VEHICLES_PATH))
	return _vehicles[kind]
