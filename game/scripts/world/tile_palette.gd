class_name TilePalette
extends Object
## Số tile Kenney (tile_NN.png) cho từng loại ô, và cách tạo TileSet từ tilesheet.

const SHEET := "res://assets/vendor/tilesheet_complete.png"
const WALL_TABLE := "res://data/wall_tiles.json"
const COLUMNS := 27

const GRASS := [1, 2, 3, 4]
const DIRT := [5, 6]
const SIDEWALK := [7, 8]
const WATER := [19, 20]
const DOCK := [42, 44]
const ASPHALT := 86
const PLAZA := [13, 14]
const PARKING := 35  # vạch trắng mép trái: lặp lại thành ô đỗ xe
const LANE_EDGE := {"<": 57, ">": 30, "v": 29, "^": 28}  # vạch vàng giữa hai làn
const TREES := [183, 186]
const TREES_ON_PAVING := [183]  # chỉ bụi xanh trên gạch/đất (bụi cam lẫn vào nền cam)
const CRATES := [129, 130, 156, 157]
const ROOF_PROPS := {
	"orange": [171, 196, 197, 198],
	"wood": [180, 205, 206, 207],
	"steel": [342, 367, 368, 369],
}
const BUILDING_STYLES := ["orange", "wood", "steel"]


static func atlas_coords(tile: int) -> Vector2i:
	return Vector2i((tile - 1) % COLUMNS, (tile - 1) / COLUMNS)


## TileSet một atlas; `solid` là danh sách tile có va chạm (giá trị: nửa cạnh hình vuông va chạm).
## `solid`: ô -> nửa cạnh khối va chạm lớp thế giới; `water`: các ô nước (lớp va chạm riêng, Jay bơi qua được).
static func build_tileset(solid: Dictionary, water: Array = []) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(Tuning.TILE, Tuning.TILE)
	for layer in [Tuning.LAYER_WORLD, Tuning.LAYER_WATER]:
		ts.add_physics_layer()
		ts.set_physics_layer_collision_layer(ts.get_physics_layers_count() - 1, layer)
		ts.set_physics_layer_collision_mask(ts.get_physics_layers_count() - 1, 0)
	var src := TileSetAtlasSource.new()
	src.texture = load(SHEET)
	src.texture_region_size = ts.tile_size
	ts.add_source(src, 0)
	var grid := Vector2i(src.texture.get_size()) / ts.tile_size
	for y in grid.y:
		for x in grid.x:
			src.create_tile(Vector2i(x, y))
	for tile in solid:
		_square(src, tile, 0, solid[tile])
	for tile in water:
		_square(src, tile, 1, Tuning.TILE / 2.0)
	return ts


static func _square(src: TileSetAtlasSource, tile: int, layer: int, half: float) -> void:
	var data := src.get_tile_data(atlas_coords(tile), 0)
	data.set_collision_polygons_count(layer, 1)
	data.set_collision_polygon_points(layer, 0, PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]))
