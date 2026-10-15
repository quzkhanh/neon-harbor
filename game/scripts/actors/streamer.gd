class_name Streamer
extends Npc
## Lucky Live: streamer tự xưng "giang hồ mạng", đứng livestream ở một góc phố (StreamerSpot). Đầu cạo, kính râm,
## dây chuyền vàng, tay cầm điện thoại, chấm đỏ "đang live". Jay ở gần thì thỉnh thoảng nói vào điện thoại; bắt chuyện
## thì chém gió; bị tấn công hay nghe súng thì tắt live bỏ chạy, một lúc sau quay về chỗ cũ.

const LIVE_LINES := ["LUCKY_LIVE_1", "LUCKY_LIVE_2", "LUCKY_LIVE_3", "LUCKY_LIVE_4", "LUCKY_LIVE_5", "LUCKY_LIVE_6",
	"LUCKY_LIVE_7", "LUCKY_LIVE_8"]
const CHAT_LINES := ["LUCKY_CHAT_1", "LUCKY_CHAT_2", "LUCKY_CHAT_3", "LUCKY_CHAT_4", "LUCKY_CHAT_5"]
const LIVE_RANGE := 420.0  # Jay ở gần chừng này thì Lucky "lên sóng"
const LIVE_EVERY := Vector2(6.0, 10.0)
const HOME_RADIUS := 20.0
const DOT_POS := Vector2(-16, -34)
const DOT_RADIUS := 4.0

var home := Vector2.ZERO
var _next_line := 2.0
var _flee_time := 0.0
var _flee_from := Vector2.ZERO


func _ready() -> void:
	skin = "manBrown"
	pose = "hold"
	heat_on_hit = Tuning.HEAT_SHOOT_PED
	heat_on_kill = Tuning.HEAT_KILL_PED
	super()
	body.add_child(Bling.new())
	home = global_position
	face(PI * 0.5)


func _think(delta: float) -> void:
	queue_redraw()
	if _flee_time > 0.0:
		_flee_time -= delta
		walk_dir((global_position - _flee_from).normalized() * Tuning.PED_FLEE_SPEED, delta)
		return
	if global_position.distance_to(home) > HOME_RADIUS:
		walk_to(home, Tuning.PED_SPEED, delta)
		return
	walk_dir(Vector2.ZERO, delta)
	var p := player()
	if not p.alive or global_position.distance_to(p.global_position) > LIVE_RANGE:
		return
	face(lerp_angle(facing, (p.global_position - global_position).angle(), minf(3.0 * delta, 1.0)))  # quay camera về Jay
	_next_line -= delta
	if _next_line <= 0.0:
		_next_line = randf_range(LIVE_EVERY.x, LIVE_EVERY.y)
		Speech.say(self, LIVE_LINES.pick_random(), {}, Palette.GOLD)


func _draw() -> void:
	super()
	if alive and _flee_time <= 0.0:
		draw_circle(DOT_POS, DOT_RADIUS + 1.5, Palette.OUTLINE)
		draw_circle(DOT_POS, DOT_RADIUS, Color(Palette.LIVE_DOT, 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.008)))


func can_chat() -> bool:
	return alive and _flee_time <= 0.0


## Nói với Jay (không phải nói vào điện thoại).
func say(key: String) -> void:
	_next_line = LIVE_EVERY.y
	Speech.say(self, key, {}, Palette.GOLD)


func chat_line() -> void:
	say(CHAT_LINES.pick_random())


func _panic(from: Vector2) -> void:
	if _flee_time <= 0.0:
		say("LUCKY_PANIC")
	_flee_from = from
	_flee_time = Tuning.PED_FLEE_TIME


func hear_gunshot(pos: Vector2, _shooter: Node) -> void:
	if alive and global_position.distance_to(pos) < Tuning.HEAR_GUNSHOT_RADIUS:
		_panic(pos)


func _on_attacked(source: Node) -> void:
	if source is Node2D:
		_panic(source.global_position)


## Phụ kiện vẽ chồng lên sprite (quay theo thân): đầu cạo, dây chuyền vàng, kính râm, điện thoại.
class Bling extends Node2D:
	const HEAD := Vector2(-2, 0.5)
	const PHONE := Rect2(15, -4, 5, 8)

	func _draw() -> void:
		draw_circle(HEAD, 7.5, Palette.LUCKY_SCALP)
		draw_arc(HEAD, 11.0, -1.1, 1.1, 10, Palette.GOLD, 2.0, true)
		draw_circle(HEAD + Vector2(11.0, 0), 1.8, Palette.GOLD)
		draw_arc(HEAD, 6.0, -0.9, 0.9, 8, Palette.SHADES, 3.0, true)
		draw_rect(PHONE, Palette.OUTLINE)
		draw_rect(PHONE.grow(-1.0), Palette.CYAN)
