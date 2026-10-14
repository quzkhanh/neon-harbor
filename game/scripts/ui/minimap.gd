class_name Minimap
extends Control
## Bản đồ thu nhỏ: biểu tượng nhiệm vụ, cửa hàng, bệnh viện, gara, tiệm sơn (MapIcon), cảnh sát, đường GPS tới mục tiêu.
## `follow`: bám quanh người chơi (góc dưới trái HUD); tắt thì hiện cả thành phố (MapScreen).

const SIZE := Vector2(210, 210)
const PX_PER_CELL := 4.0
const DOT := 4.0
const EDGE := 7.0
const ROUTE_WIDTH := 3.0
const ROUTE_REFRESH := 0.5

static var _tex_cache := {}  # MapData -> ImageTexture (dựng một lần cho mỗi bản đồ)

var city: City
var follow := true
var px_per_cell := PX_PER_CELL
var _route := PackedVector2Array()
var _route_timer := 0.0


func _init(c: City, view_size := SIZE, scale_px := PX_PER_CELL, follow_player := true) -> void:
	city = c
	follow = follow_player
	px_per_cell = scale_px
	custom_minimum_size = view_size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func texture_for(data: MapData) -> ImageTexture:
	if not _tex_cache.has(data):
		_tex_cache.clear()
		var img := Image.create(data.size.x, data.size.y, false, Image.FORMAT_RGBA8)
		for y in data.size.y:
			for x in data.size.x:
				var cell := Vector2i(x, y)
				var ch := data.at(cell)
				var key := "road" if data.is_road(cell) else (ch if Palette.MAP_COLORS.has(ch) else data.floor_of(cell))
				img.set_pixel(x, y, Palette.MAP_COLORS.get(key, Palette.MAP_COLORS[","]))
		_tex_cache[data] = ImageTexture.create_from_image(img)
	return _tex_cache[data]


func _process(delta: float) -> void:
	_route_timer -= delta
	if _route_timer <= 0.0:
		_route_timer = ROUTE_REFRESH
		_update_route()
	queue_redraw()


## Đường GPS tới mục tiêu: theo lòng đường khi đang lái, theo lối đi bộ khi đi bộ.
func _update_route() -> void:
	var target := city.missions.target()
	var p := city.player
	_route = PackedVector2Array()
	if target and p.alive:
		_route = city.path(p.global_position, target.global_position, p.vehicle != null)


func to_map(world: Vector2) -> Vector2:
	var center := city.player.global_position if follow else city.data.world_rect().get_center()
	return size * 0.5 + (world - center) / Tuning.TILE * px_per_cell


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.BG)
	draw_texture_rect(texture_for(city.data), Rect2(to_map(Vector2.ZERO), Vector2(city.data.size) * px_per_cell), false)
	var target := city.missions.target()
	if target and _route.size() > 1:
		var pts := PackedVector2Array([to_map(city.player.global_position)])
		for w in _route.slice(1):
			pts.append(to_map(w))
		draw_polyline(pts, Palette.OUTLINE, ROUTE_WIDTH + 2.0, true)
		draw_polyline(pts, target.color, ROUTE_WIDTH, true)
	for c in city.police.cops():
		if c.alive:
			_dot(c.global_position, Palette.SIREN_BLUE)
	for g in get_tree().get_nodes_in_group("gang"):
		if g.alive:
			_dot(g.global_position, Palette.HEALTH)
	var markers := get_tree().get_nodes_in_group("markers")
	var nearest := _nearest_by_icon(markers)
	for m in markers:
		var pos := to_map(m.global_position)
		var inside := Rect2(Vector2.ZERO, size).grow(-EDGE).has_point(pos)
		if inside or m is Marker or nearest[m.icon] == m:
			MapIcon.draw(self, pos.clamp(Vector2.ONE * EDGE * 1.5, size - Vector2.ONE * EDGE * 1.5), m.icon, m.color)
	var p := city.player
	var angle := p.vehicle.rotation if p.vehicle else p.aim_angle
	var c := to_map(p.global_position)
	var pts := PackedVector2Array([c + Vector2(9, 0).rotated(angle), c + Vector2(-6, 6).rotated(angle), c + Vector2(-6, -6).rotated(angle)])
	draw_colored_polygon(pts, Color.WHITE)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Palette.OUTLINE, 1.5, true)


## Biển hiệu gần người chơi nhất của từng loại (chỉ chúng được ghim ở mép khi ngoài khung).
func _nearest_by_icon(markers: Array[Node]) -> Dictionary:
	var from := city.player.global_position
	var best := {}
	for m in markers:
		if m is SignPost and (not best.has(m.icon) or from.distance_to(m.global_position) < from.distance_to(best[m.icon].global_position)):
			best[m.icon] = m
	return best


## Chấm người (cảnh sát, băng đảng); ngoài khung thì không vẽ.
func _dot(world: Vector2, color: Color) -> void:
	var pos := to_map(world)
	if not Rect2(Vector2.ZERO, size).grow(-EDGE).has_point(pos):
		return
	draw_circle(pos, DOT + 2.0, Palette.OUTLINE)
	draw_circle(pos, DOT, color)
