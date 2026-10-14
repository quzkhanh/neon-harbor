class_name Missions
extends Node
## Điều phối nhiệm vụ: điểm nhận nhiệm vụ kế tiếp, hội thoại mở đầu/kết thúc, thưởng, thất bại.

const SCRIPTS := {
	1: "res://scripts/missions/mission1.gd",
	2: "res://scripts/missions/mission2.gd",
	3: "res://scripts/missions/mission3.gd",
}

const GIVER_OFFSET := Vector2(52, -8)

var city: City
var current: MissionBase
var current_n := 0
var retry_mission := 0  # nhiệm vụ vừa thất bại vì người chơi chết (màn chết cho thử lại)
var _start_marker: Marker
var _busy := false


func _init(c: City) -> void:
	city = c
	name = "Missions"


func _ready() -> void:
	_refresh_marker()
	for n in range(1, Game.MISSION_COUNT + 1):
		_place_giver(giver_pos(n) + GIVER_OFFSET)


## Rosa đứng cạnh mỗi điểm nhận nhiệm vụ (chỉ để nhìn, không tương tác vật lý).
func _place_giver(pos: Vector2) -> void:
	var rosa := Sprite2D.new()
	rosa.texture = load(Human.CHAR_DIR % ["womanGreen", "stand"])
	rosa.centered = false
	rosa.offset = -Human.BODY_PIVOT
	rosa.global_position = pos
	rosa.rotation = PI
	city.effects.add_child(rosa)


func giver_pos(n: int) -> Vector2:
	return cell_pos_of(str(n))


func cell_pos_of(ch: String) -> Vector2:
	return MapData.cell_center(city.data.find(ch))


## Điểm cần tới lúc này (đích của nhiệm vụ đang làm, hoặc điểm nhận nhiệm vụ kế tiếp) để chỉ đường.
func target() -> Marker:
	var m: Marker = current.marker() if current else _start_marker
	return m if is_instance_valid(m) else null


func _refresh_marker() -> void:
	if _start_marker:
		_start_marker.queue_free()
		_start_marker = null
	var n := Game.next_mission()
	if n > 0 and current == null:
		_start_marker = Marker.make(city.effects, giver_pos(n), Palette.MARKER_MISSION, Game.mission(n).title)


func _process(_delta: float) -> void:
	var n := Game.next_mission()
	if current or _busy or n == 0 or not city.player.alive or get_tree().paused:
		return
	if city.player.global_position.distance_to(giver_pos(n)) < Tuning.MISSION_RADIUS:
		start(n)


func start(n: int, intro := true) -> void:
	_busy = true
	if city.player.vehicle:
		city.player.exit_vehicle()
	if intro:
		await city.overlays.show_dialog(Game.mission(n).intro)
	_busy = false
	current_n = n
	current = load(SCRIPTS[n]).new()
	current.city = city
	current.completed.connect(_on_completed.bind(n))
	current.failed.connect(_on_failed)
	add_child(current)
	_refresh_marker()


func _on_completed(n: int) -> void:
	_end_current()
	Sfx.play("mission_complete")
	await city.overlays.show_dialog(Game.mission(n).outro)
	var unlocked := Game.complete_mission(n)
	var reward := int(Game.mission(n).reward)
	await city.overlays.show_mission_complete(n, reward, unlocked)
	await Ads.show_interstitial("after_mission")
	if n == Game.MISSION_COUNT:
		Game.go(Game.ENDING_SCENE)
	_refresh_marker()


func _on_failed(reason_key: String) -> void:
	_end_current()
	Game.clear_objective()
	Sfx.play("mission_fail")
	Game.notice.emit(I18n.fmt("NOTICE_MISSION_FAILED", {"reason": tr(reason_key)}))
	_refresh_marker()


func _end_current() -> void:
	if current:
		current.cleanup()
		current.queue_free()
		current = null


func on_player_died() -> void:
	if current:
		retry_mission = current_n
		_on_failed("FAIL_DIED")

