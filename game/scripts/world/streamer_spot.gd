class_name StreamerSpot
extends Node
## Góc phố của Lucky Live: biển neon (có biểu tượng trên bản đồ), giữ Lucky luôn có mặt (chết thì một lúc sau, khi góc
## phố khuất màn hình, có Lucky mới), gợi ý bắt chuyện và việc vặt lấy lại điện thoại bị giật (activity_phone.gd).

const CELL := Vector2i(104, 156)
const SIGN_CELL := Vector2i(103, 154)
const TALK_RADIUS := 60.0
const RESPAWN := 60.0
const JOB_CHANCE := 0.5
const JOB_COOLDOWN := 90.0

var city: City
var lucky: Streamer
var _respawn := 0.0
var _job_wait := 0.0  # giây nữa Lucky mới nhờ việc lần tiếp


func _init(c: City) -> void:
	city = c
	name = "StreamerSpot"


func _ready() -> void:
	SignPost.make(city.effects, MapData.cell_center(SIGN_CELL), Palette.ICON_STREAMER, "SIGN_LUCKY", MapIcon.Kind.STREAMER)
	_spawn()


func _process(delta: float) -> void:
	_job_wait -= delta
	if is_instance_valid(lucky) and lucky.alive:
		return
	_respawn -= delta
	if _respawn <= 0.0 and not city.view_rect().has_point(MapData.cell_center(CELL)):
		_spawn()


func _spawn() -> void:
	lucky = city.spawn_npc(Streamer, MapData.cell_center(CELL))
	lucky.died.connect(func(_h: Human) -> void: _respawn = RESPAWN)


## Gợi ý + hành động khi Jay đi bộ cạnh Lucky (Interactions gọi): [khoá, Callable] hoặc [].
func prompt() -> Array:
	var p := city.player
	if p.vehicle or not is_instance_valid(lucky) or not lucky.can_chat() or p.global_position.distance_to(lucky.global_position) > TALK_RADIUS:
		return []
	return ["HINT_TALK", _talk]


func _talk() -> void:
	if _job_wait <= 0.0 and not city.activities.busy() and randf() < JOB_CHANCE:
		_job_wait = JOB_COOLDOWN
		city.activities.start("phone")
	else:
		lucky.chat_line()
