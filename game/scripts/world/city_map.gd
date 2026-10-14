class_name CityMap
extends Node2D
## Dựng các TileMapLayer (nền, đường, toà nhà/va chạm, đồ trên mái) từ MapData.

const MAP_PATH := "res://maps/city.txt"
const TENTS := ["res://assets/vendor/objects/tent_red.png", "res://assets/vendor/objects/tent_blue.png"]
const TENT_SCALE := 0.62
const NEON_EVERY := 5
const NEON_SCALE := Vector2(0.9, 0.14)
const TREE_HALF := 22.0
const PAVED := [":", "."]
const CRATE_HALF := 26.0
const LAMP_EVERY := 7
const LAMP_SCALE := 1.5

var data: MapData
var _ground: TileMapLayer
var _walls: TileMapLayer
var _props: TileMapLayer
var _wall_table: Dictionary


func build(map: MapData = null) -> void:
	data = map if map else MapData.load_file(MAP_PATH)
	_wall_table = JSON.parse_string(FileAccess.get_file_as_string(TilePalette.WALL_TABLE))
	var solid := {}
	for t in TilePalette.WATER:
		solid[t] = Tuning.TILE / 2.0
	for style in _wall_table:
		for t in _wall_table[style].values():
			solid[int(t)] = Tuning.TILE / 2.0
	for t in TilePalette.TREES:
		solid[t] = TREE_HALF
	for t in TilePalette.CRATES:
		solid[t] = CRATE_HALF
	var tileset := TilePalette.build_tileset(solid)
	_ground = _layer("Ground", tileset, -20)
	add_child(Crosswalks.new(data))
	_walls = _layer("Walls", tileset, 20)
	_props = _layer("Props", tileset, 21)
	_paint_floors()
	var depth := BuildingDepth.new()
	depth.name = "BuildingDepth"
	depth.z_index = 22
	add_child(depth)
	depth.build(data, tileset, _walls, _wall_table)
	_paint_shadows(tileset)
	_place_lamps()
	_place_neon()
	_place_tents()


func _layer(layer_name: String, tileset: TileSet, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tileset
	layer.z_index = z
	add_child(layer)
	return layer


func _paint_floors() -> void:
	for y in data.size.y:
		for x in data.size.x:
			var cell := Vector2i(x, y)
			var ch := data.at(cell)
			_put(_ground, cell, _floor_tile(cell, data.floor_of(cell)))
			if ch == "T":
				var trees := TilePalette.TREES_ON_PAVING if data.floor_of(cell) in PAVED else TilePalette.TREES
				_put(_props, cell, _pick(trees, cell))
			elif ch == "x":
				_put(_props, cell, _pick(TilePalette.CRATES, cell))


func _floor_tile(cell: Vector2i, ch: String) -> int:
	match ch:
		"\"":
			return _pick(TilePalette.GRASS, cell)
		":":
			return _pick(TilePalette.PLAZA, cell)
		".":
			return _pick(TilePalette.DIRT, cell)
		"~":
			return _pick(TilePalette.WATER, cell)
		"_":
			return _pick(TilePalette.DOCK, cell)
		"-":
			return TilePalette.PARKING
		"+", "=":
			return TilePalette.ASPHALT
		"<", ">", "^", "v":
			var d := data.lane_dir(cell)
			var across := Vector2i(d.y, -d.x)  # phía tay trái người lái = làn ngược chiều
			if data.lane_dir(cell + across) == -d:
				return TilePalette.LANE_EDGE[ch]
			return TilePalette.ASPHALT
	return _pick(TilePalette.SIDEWALK, cell)


## Bóng đổ của nhà, cây, thùng: chép ô sang một lớp đen mờ, lệch chéo, nằm trên mặt đất và dưới người/xe.
func _paint_shadows(tileset: TileSet) -> void:
	var shadows := _layer("Shadows", tileset, -18)
	shadows.collision_enabled = false
	shadows.modulate = Palette.GROUND_SHADOW
	shadows.position = Tuning.SHADOW_OFFSET
	for layer in [_walls, _props]:
		for cell in layer.get_used_cells():
			shadows.set_cell(cell, 0, layer.get_cell_atlas_coords(cell))


## Đèn đường: quầng sáng ấm trên vỉa hè sát đường, cách đều nhau.
func _place_lamps() -> void:
	var lamps := _decor_layer("Lamps", 19)
	var tex := Fx.tex("glow")
	for y in data.size.y:
		for x in data.size.x:
			var cell := Vector2i(x, y)
			if data.at(cell) != "," or (x + y) % LAMP_EVERY != 0:
				continue
			for d in MapData.DIRS:
				if data.lane_dir(cell + d) != Vector2i.ZERO:
					var glow := Sprite2D.new()
					glow.texture = tex
					glow.material = Fx.additive()
					glow.modulate = Palette.LAMP
					glow.scale = Vector2.ONE * LAMP_SCALE
					glow.position = MapData.cell_center(cell) + Vector2(d) * Tuning.TILE * 0.3
					lamps.add_child(glow)
					break


## Dải đèn neon dưới mép mái các mặt tiền nhìn ra phố (nhịp ngẫu nhiên theo ô, màu xoay vòng).
func _place_neon() -> void:
	var neon := _decor_layer("Neon", 21)
	var tex := Fx.tex("glow")
	for y in data.size.y:
		for x in data.size.x:
			var cell := Vector2i(x, y)
			if data.at(cell) != "#" or not data.is_ped_walkable(cell + Vector2i.DOWN) or hash_cell(cell) % NEON_EVERY != 0:
				continue
			var glow := Sprite2D.new()
			glow.texture = tex
			glow.material = Fx.additive()
			glow.modulate = Palette.NEON[hash_cell(cell) % Palette.NEON.size()]
			glow.scale = NEON_SCALE
			glow.position = MapData.cell_center(cell) + Vector2(0, Tuning.TILE * 0.5)
			neon.add_child(glow)


## Lều sạp chợ: che phía trên đầu người (đi xuyên qua được).
func _place_tents() -> void:
	var tents := _decor_layer("Tents", 21)
	for cell in data.find_all("M"):
		var s := Sprite2D.new()
		s.texture = load(TENTS[hash_cell(cell) % TENTS.size()])
		s.scale = Vector2.ONE * TENT_SCALE
		s.position = MapData.cell_center(cell)
		tents.add_child(s)


func _decor_layer(layer_name: String, z: int) -> Node2D:
	var n := Node2D.new()
	n.name = layer_name
	n.z_index = z
	add_child(n)
	return n


func _put(layer: TileMapLayer, cell: Vector2i, tile: int) -> void:
	layer.set_cell(cell, 0, TilePalette.atlas_coords(tile))


func _pick(options: Array, cell: Vector2i) -> int:
	return options[hash_cell(cell) % options.size()]


static func hash_cell(cell: Vector2i) -> int:
	return absi(cell.x * 73856093 ^ cell.y * 19349663) % 1000003
