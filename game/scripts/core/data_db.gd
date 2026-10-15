class_name DataDB
extends Object
## Bảng súng, xe và các khu của thành phố đọc từ data/*.json (thêm súng/xe = thêm dữ liệu).

const WEAPONS_PATH := "res://data/weapons.json"
const VEHICLES_PATH := "res://data/vehicles.json"
const DISTRICTS_PATH := "res://data/districts.json"  # sinh bởi tools/maps/build_city.py
const EXTRAS_PATH := "res://data/extras.json"  # tuyến đua, dốc nhảy, bến thuyền (cũng sinh bởi build_city.py)

static var _weapons: Array = []
static var _vehicles: Dictionary = {}
static var _districts: Array = []
static var _extras: Dictionary = {}


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
	return vehicles()[kind]


static func vehicles() -> Dictionary:
	if _vehicles.is_empty():
		_vehicles = JSON.parse_string(FileAccess.get_file_as_string(VEHICLES_PATH))
	return _vehicles


## Loại xe ngẫu nhiên cho dòng xe và xe đỗ ven đường, theo trọng số "traffic".
static func traffic_kind() -> String:
	var total := 0.0
	for k in vehicles():
		total += float(vehicles()[k].traffic)
	var roll := randf() * total
	for k in vehicles():
		roll -= float(vehicles()[k].traffic)
		if roll < 0.0:
			return k
	return "car"


## {"races": [{"start": [x, y], "heading": [dx, dy], "points": [[x, y]...]}], "ramps": [[x, y, dx, dy]], "boats": [[x, y]]}
## (toạ độ theo ô; điểm checkpoint là tâm giao lộ nên có thể là số nguyên = mép ô).
static func extras() -> Dictionary:
	if _extras.is_empty():
		_extras = JSON.parse_string(FileAccess.get_file_as_string(EXTRAS_PATH))
	return _extras


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
