class_name Minimap
extends Control
## Minimap góc dưới trái: bản đồ thu nhỏ quanh người chơi, điểm nhiệm vụ, cửa hàng, bệnh viện, gara, cảnh sát.

const SIZE := Vector2(210, 210)
const PX_PER_CELL := 4.0
const DOT := 4.0
const EDGE := 7.0

var city: City
var _tex: ImageTexture


func _init(c: City) -> void:
	city = c
	custom_minimum_size = SIZE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _ready() -> void:
	var data := city.data
	var img := Image.create(data.size.x, data.size.y, false, Image.FORMAT_RGBA8)
	for y in data.size.y:
		for x in data.size.x:
			var cell := Vector2i(x, y)
			var ch := data.at(cell)
			var key := "road" if data.is_road(cell) else (ch if Palette.MAP_COLORS.has(ch) else data.floor_of(cell))
			img.set_pixel(x, y, Palette.MAP_COLORS.get(key, Palette.MAP_COLORS[","]))
	_tex = ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	queue_redraw()


func _to_map(world: Vector2) -> Vector2:
	var center := city.player.global_position
	return SIZE * 0.5 + (world - center) / Tuning.TILE * PX_PER_CELL


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Palette.BG)
	var origin := _to_map(Vector2.ZERO)
	draw_texture_rect(_tex, Rect2(origin, Vector2(city.data.size) * PX_PER_CELL), false)
	for c in city.police.cops():
		if c.alive:
			_dot(c.global_position, Palette.SIREN_BLUE, false)
	for g in get_tree().get_nodes_in_group("gang"):
		if g.alive:
			_dot(g.global_position, Palette.HEALTH, false)
	for m in get_tree().get_nodes_in_group("markers"):
		_dot(m.global_position, m.color, true)
	var p := city.player
	var angle := p.vehicle.rotation if p.vehicle else p.aim_angle
	var c := SIZE * 0.5
	var pts := PackedVector2Array([c + Vector2(9, 0).rotated(angle), c + Vector2(-6, 6).rotated(angle), c + Vector2(-6, -6).rotated(angle)])
	draw_colored_polygon(pts, Color.WHITE)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Palette.OUTLINE, 1.5, true)


## Chấm trên minimap; điểm quan trọng nằm ngoài khung thì ghim vào mép.
func _dot(world: Vector2, color: Color, pin: bool) -> void:
	var pos := _to_map(world)
	var inside := Rect2(Vector2.ZERO, SIZE).grow(-EDGE).has_point(pos)
	if not inside:
		if not pin:
			return
		pos = pos.clamp(Vector2.ONE * EDGE, SIZE - Vector2.ONE * EDGE)
	draw_circle(pos, DOT + 2.0, Palette.OUTLINE)
	draw_circle(pos, DOT, color)
