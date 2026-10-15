class_name Activities
extends Node
## Việc phụ lặp lại được: đua xe bắt đầu khi dừng xe trên cờ đua (Q) chừng một giây (phím E trong xe luôn là xuống xe);
## giao hàng (J), càn quét (K) bắt đầu bằng phím tương tác khi đứng ở cửa; taxi và tuần tra tự quản tự bắt đầu khi lái
## đúng loại xe. Mỗi lúc chỉ một việc, và không chạy
## song song với nhiệm vụ chính. Việc phụ tự trả tiền và báo kết quả; ở đây chỉ dọn dẹp.

const SCRIPTS := {
	"race": "res://scripts/missions/activity_race.gd",
	"delivery": "res://scripts/missions/activity_delivery.gd",
	"sweep": "res://scripts/missions/activity_sweep.gd",
	"taxi": "res://scripts/missions/activity_taxi.gd",
	"vigilante": "res://scripts/missions/activity_vigilante.gd",
	"errand": "res://scripts/missions/activity_errand.gd",
	"phone": "res://scripts/missions/activity_phone.gd",
}
const STARTS := [["Q", "SIGN_RACE", Palette.ICON_RACE, MapIcon.Kind.RACE], ["J", "SIGN_JOB", Palette.ICON_JOB, MapIcon.Kind.JOB],
	["K", "SIGN_SWEEP", Palette.ICON_SWEEP, MapIcon.Kind.SWEEP]]
const START_RADIUS := 90.0  # trong xe (điểm đua nằm cạnh đường)
const DOOR_RADIUS := 45.0  # đi bộ: phải đứng ngay cửa, kẻo che mất gợi ý lên xe đỗ gần đó

var city: City
var current: MissionBase
var kind := ""
var _starts := {}  # ký hiệu -> Array[Vector2]
var _race_wait := 0.0  # giây đã dừng xe trên cờ đua
var _race_told := false
var _done_in := 0  # id xe vừa xong việc tự bắt đầu (taxi, tuần tra): chờ đổi xe mới bắt đầu lại


func _init(c: City) -> void:
	city = c
	name = "Activities"


func _ready() -> void:
	for def in STARTS:
		var spots: Array[Vector2] = []
		for cell in city.data.find_all(def[0]):
			spots.append(MapData.cell_center(cell))
			SignPost.make(city.effects, MapData.cell_center(cell), def[2], def[1], def[3])
		_starts[def[0]] = spots


func busy() -> bool:
	return current != null or city.missions.current != null


func _process(delta: float) -> void:
	var v := city.player.vehicle
	var id := v.get_instance_id() if v else 0
	if id != _done_in:
		_done_in = 0
	if busy() or v == null or id == _done_in or Game.stars > 0 or get_tree().paused:
		return
	if v.kind == "taxi":
		start("taxi")
	elif v.kind == "police":
		start("vigilante")
	else:
		_wait_on_flag(v, delta)


## Đứng trên cờ đua: báo một lần; dừng hẳn đủ lâu thì xuất phát.
func _wait_on_flag(v: Vehicle, delta: float) -> void:
	var flag := -1
	for i in _starts.Q.size():
		if v.global_position.distance_to(_starts.Q[i]) < START_RADIUS:
			flag = i
	if flag < 0:
		_race_wait = 0.0
		_race_told = false
		return
	if not _race_told:
		_race_told = true
		Game.notice.emit(tr("NOTICE_RACE_STOP"))
	_race_wait = _race_wait + delta if v.velocity.length() < Tuning.RACE_STOP_SPEED else 0.0
	if _race_wait >= Tuning.RACE_STOP_TIME:
		_race_wait = 0.0
		start("race", _race_index(_starts.Q[flag]))


## Gợi ý + hành động ở điểm xuất phát gần người chơi (Interactions gọi): [khoá, Callable] hoặc [].
func prompt() -> Array:
	if busy():
		return []
	var p := city.player
	var pos := p.vehicle.global_position if p.vehicle else p.global_position
	var radius := START_RADIUS if p.vehicle else DOOR_RADIUS
	var near := func(ch: String) -> int:
		for i in _starts[ch].size():
			if pos.distance_to(_starts[ch][i]) < radius:
				return i
		return -1
	if near.call("J") >= 0 and not p.vehicle:  # trong xe thì E vẫn là xuống xe
		return ["HINT_DELIVERY", start.bind("delivery")]
	if near.call("K") >= 0 and not p.vehicle:
		return ["HINT_SWEEP", start.bind("sweep")]
	return []


## Tuyến đua có ô xuất phát gần điểm Q này nhất.
func _race_index(spot: Vector2) -> int:
	var races: Array = DataDB.extras().races
	var best := 0
	for i in races.size():
		var s: Array = races[i].start
		var b: Array = races[best].start
		if spot.distance_to(MapData.cell_center(Vector2i(int(s[0]), int(s[1])))) < spot.distance_to(MapData.cell_center(Vector2i(int(b[0]), int(b[1])))):
			best = i
	return best


## `index`: tuyến đua; `asker`: người nhờ việc vặt.
func start(job: String, index := 0, asker: Pedestrian = null) -> void:
	if busy():
		return
	kind = job
	current = load(SCRIPTS[job]).new()
	current.city = city
	if job == "race":
		current.index = index
	elif job == "errand":
		current.asker = asker
	current.completed.connect(_end.bind(current))
	current.failed.connect(_on_failed.bind(current))
	add_child(current)


func _on_failed(reason_key: String, job: MissionBase) -> void:
	if job != current:
		return
	_end(job)
	Sfx.play("mission_fail")
	Game.notice.emit(I18n.fmt("NOTICE_JOB_FAILED", {"reason": tr(reason_key)}))


func _end(job: MissionBase) -> void:
	if job != current:
		return
	if kind in ["taxi", "vigilante"] and city.player.vehicle:
		_done_in = city.player.vehicle.get_instance_id()
	if current:
		current.cleanup()
		current.queue_free()
		current = null
	kind = ""
	Game.clear_objective()


## Người chơi chết: bỏ việc phụ đang làm.
func on_player_died() -> void:
	if current:
		_on_failed("FAIL_DIED", current)
