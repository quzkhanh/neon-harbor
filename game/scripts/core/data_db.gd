class_name DataDB
extends Object
## Bảng súng, xe và các khu của thành phố đọc từ data/*.json (thêm súng/xe = thêm dữ liệu).

const WEAPONS_PATH := "res://data/weapons.json"
const VEHICLES_PATH := "res://data/vehicles.json"
const DISTRICTS_PATH := "res://data/districts.json"  # sinh bởi tools/maps/build_city.py

static var _weapons: Array = []
static var _vehicles: Dictionary = {}
static var _districts: Array = []


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


## Các khu: [{"key": khoá tên khu, "rect": [x, y, rộng, cao] theo ô}].
static func districts() -> Array:
	if _districts.is_empty():
		_districts = JSON.parse_string(FileAccess.get_file_as_string(DISTRICTS_PATH))
	return _districts


## Khoá tên khu chứa ô `cell` ("" nếu không thuộc khu nào).
static func district_at(cell: Vector2i) -> String:
	for d in districts():
		var r: Array = d.rect
		if Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])).has_point(cell):
			return d.key
	return ""
