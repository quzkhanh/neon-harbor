class_name CityMap
extends Node2D
## Dựng các TileMapLayer (nền, đường, toà nhà/va chạm, đồ trên mái) từ MapData.

const MAP_PATH := "res://maps/city.txt"
const TENTS := ["res://assets/vendor/objects/tent_red.png", "res://assets/vendor/objects/tent_blue.png"]
const TENT_SCALE := 0.62
const NEON_EVERY := 5
const NEON_SCALE := Vector2(0.9, 0.14)
const TREE_HALF := 22.0
const CRATE_HALF := 26.0
const ROOF_PROP_EVERY := 7
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
	_paint_buildings()
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
				_put(_props, cell, _pick(TilePalette.TREES, cell))
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


func _paint_buildings() -> void:
	var style_of := _building_styles()
	for cell in style_of:
		var style: String = style_of[cell]
		var sig := _signature(cell)
		var table: Dictionary = _wall_table[style]
		_put(_walls, cell, int(table.get(str(sig), table["0"])))
		if sig == 0 and _hash(cell) % ROOF_PROP_EVERY == 0:
			_put(_props, cell, _pick(TilePalette.ROOF_PROPS[style], cell))


## Mỗi khối nhà liền nhau nhận một kiểu viền, xoay vòng theo thứ tự quét.
func _building_styles() -> Dictionary:
	var style_of := {}
	var index := 0
	for y in data.size.y:
		for x in data.size.x:
			var start := Vector2i(x, y)
			if data.at(start) != "#" or style_of.has(start):
				continue
			var style: String = TilePalette.BUILDING_STYLES[index % TilePalette.BUILDING_STYLES.size()]
			index += 1
			var stack: Array[Vector2i] = [start]
			style_of[start] = style
			while stack.size() > 0:
				var c: Vector2i = stack.pop_back()
				for d in MapData.DIRS:
					var n: Vector2i = c + d
					if data.at(n) == "#" and data.in_bounds(n) and not style_of.has(n):
						style_of[n] = style
						stack.append(n)
	return style_of


## Bit T,R,B,L,tl,tr,br,bl bật khi đoạn biên đó có viền (khớp tools/assets/build_wall_table.py).
func _signature(cell: Vector2i) -> int:
	var open := func(dx: int, dy: int) -> bool: return data.at(cell + Vector2i(dx, dy)) != "#"
	var t: bool = open.call(0, -1)
	var r: bool = open.call(1, 0)
	var b: bool = open.call(0, 1)
	var l: bool = open.call(-1, 0)
	var bits := [t, r, b, l,
		t or l or open.call(-1, -1), t or r or open.call(1, -1),
		b or r or open.call(1, 1), b or l or open.call(-1, 1)]
	var sig := 0
	for i in bits.size():
		if bits[i]:
			sig |= 1 << i
	return sig


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
	var neon := _decor_layer("Neon", 22)
	var tex := Fx.tex("glow")
	for y in data.size.y:
		for x in data.size.x:
			var cell := Vector2i(x, y)
			if data.at(cell) != "#" or not data.is_ped_walkable(cell + Vector2i.DOWN) or _hash(cell) % NEON_EVERY != 0:
				continue
			var glow := Sprite2D.new()
			glow.texture = tex
			glow.material = Fx.additive()
			glow.modulate = Palette.NEON[_hash(cell) % Palette.NEON.size()]
			glow.scale = NEON_SCALE
			glow.position = MapData.cell_center(cell) + Vector2(0, Tuning.TILE * 0.5)
			neon.add_child(glow)


## Lều sạp chợ: che phía trên đầu người (đi xuyên qua được).
func _place_tents() -> void:
	var tents := _decor_layer("Tents", 21)
	for cell in data.find_all("M"):
		var s := Sprite2D.new()
		s.texture = load(TENTS[_hash(cell) % TENTS.size()])
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
	return options[_hash(cell) % options.size()]


func _hash(cell: Vector2i) -> int:
	return absi(cell.x * 73856093 ^ cell.y * 19349663) % 1000003
