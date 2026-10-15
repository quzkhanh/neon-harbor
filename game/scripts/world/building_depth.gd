class_name BuildingDepth
extends Node2D
## Nhà nổi khối kiểu game hành động nhìn từ trên xuống cổ điển: chân nhà (lớp Walls, có va chạm) đứng yên; các lớp tường và mái phóng quanh tâm camera,
## nên nhà càng xa tâm màn hình thì mái càng lệch ra ngoài và lộ thành tường phía hướng về người chơi.

const SLICES := 4  # số lớp tường giữa chân nhà và mái
const ROOF_PROP_EVERY := 7
const TINT_SHADER := "res://assets/shaders/tint_toward.gdshader"

var _layers: Array[TileMapLayer] = []
var _rise: Array[float] = []
var _views: Array[Transform2D] = []  # transform hiển thị từng lớp, đặt thẳng vào RenderingServer
var _alts := {}  # "tile:style:level" -> id ô thay thế mang màu riêng
var _source: TileSetAtlasSource


func build(data: MapData, tileset: TileSet, walls: TileMapLayer, wall_table: Dictionary) -> void:
	process_priority = 1  # sau CameraRig: dùng tâm camera (kể cả rung) của chính frame này
	_source = tileset.get_source(0)
	walls.modulate = Palette.WALL_BASE
	var heights := [Tuning.BUILDING_RISE_LOW, Tuning.BUILDING_RISE_HIGH]
	var roof_tint := _tint(Tuning.ROOF_TINT_AMOUNT)
	var wall_tint := _tint(Tuning.WALL_TINT_AMOUNT)
	var stacks := []
	for h in heights.size():
		var stack: Array[TileMapLayer] = []
		for level in range(1, SLICES + 2):  # SLICES lớp tường, lớp cuối là mái
			var layer_name := "Roof%d" % h if level == SLICES + 1 else "Wall%d_%d" % [h, level]
			var layer := _layer(tileset, heights[h] * level / float(SLICES + 1), layer_name)
			layer.material = roof_tint if level == SLICES + 1 else wall_tint
			stack.append(layer)
		stack.append(_layer(tileset, heights[h], "RoofProps%d" % h))
		stacks.append(stack)
	var blocks := _blocks(data)
	for cell in blocks:
		var block: int = blocks[cell]
		var style: String = TilePalette.BUILDING_STYLES[block % TilePalette.BUILDING_STYLES.size()]
		var table: Dictionary = wall_table[style]
		var sig := _signature(data, cell)
		var tile := int(table.get(str(sig), table["0"]))
		var coords := TilePalette.atlas_coords(tile)
		walls.set_cell(cell, 0, coords)
		var stack: Array[TileMapLayer] = stacks[CityMap.hash_cell(Vector2i(block, 0)) % heights.size()]
		for level in range(1, SLICES + 2):
			stack[level - 1].set_cell(cell, 0, coords, _alt(tile, style, level))
		if sig == 0 and CityMap.hash_cell(cell) % ROOF_PROP_EVERY == 0:
			var props: Array = TilePalette.ROOF_PROPS[style]
			stack[SLICES + 1].set_cell(cell, 0, TilePalette.atlas_coords(props[CityMap.hash_cell(cell) % props.size()]))


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	# Tâm khung hình thật (đã qua limit_* và rung), để mái khớp với mặt đất ở mọi chỗ, kể cả sát biên map.
	_apply(camera.get_screen_center_position())


## Không đổi scale/position của node: TileMapLayer sẽ cập nhật lại mọi ô mỗi frame (~3,5 ms). Chỉ dịch phần vẽ.
func _apply(center: Vector2) -> void:
	for i in _layers.size():
		_views[i] = Transform2D(0.0, Vector2.ONE * (1.0 + _rise[i]), 0.0, -center * _rise[i])
		RenderingServer.canvas_item_set_transform(_layers[i].get_canvas_item(), _views[i])


## Transform đang hiển thị của lớp thứ `i` (con thứ `i`).
func view_transform(i: int) -> Transform2D:
	return _views[i]


func _layer(tileset: TileSet, rise: float, layer_name: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tileset
	layer.collision_enabled = false
	add_child(layer)
	_layers.append(layer)
	_rise.append(rise)
	_views.append(Transform2D.IDENTITY)
	return layer


func _tint(amount: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(TINT_SHADER)
	m.set_shader_parameter("amount", amount)
	return m


## Ô thay thế của `tile` nhuộm màu theo kiểu nhà: lớp tường tối dần về phía chân, lớp cuối là màu mái.
func _alt(tile: int, style: String, level: int) -> int:
	var key := "%d:%s:%d" % [tile, style, level]
	if not _alts.has(key):
		var coords := TilePalette.atlas_coords(tile)
		var id := _source.create_alternative_tile(coords)
		var shade: Color = Palette.WALL_SHADE[style].darkened(Tuning.WALL_DARKEN * float(SLICES - level) / SLICES)
		_source.get_tile_data(coords, id).modulate = Palette.ROOF_TINT[style] if level > SLICES else shade
		_alts[key] = id
	return _alts[key]


## Đánh số các khối nhà liền nhau (ô "#") theo thứ tự quét.
static func _blocks(data: MapData) -> Dictionary:
	var block_of := {}
	var index := 0
	for y in data.size.y:
		for x in data.size.x:
			var start := Vector2i(x, y)
			if data.at(start) != "#" or block_of.has(start):
				continue
			var stack: Array[Vector2i] = [start]
			block_of[start] = index
			while stack.size() > 0:
				var c: Vector2i = stack.pop_back()
				for d in MapData.DIRS:
					var n: Vector2i = c + d
					if data.at(n) == "#" and data.in_bounds(n) and not block_of.has(n):
						block_of[n] = index
						stack.append(n)
			index += 1
	return block_of


## Bit T,R,B,L,tl,tr,br,bl bật khi đoạn biên đó có viền (khớp tools/assets/build_wall_table.py).
static func _signature(data: MapData, cell: Vector2i) -> int:
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
