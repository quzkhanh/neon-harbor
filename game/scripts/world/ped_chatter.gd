class_name PedChatter
extends Node
## Hội thoại tự phát giữa hai người đi đường đứng gần nhau quanh Jay: hai người dừng lại, quay vào nhau và
## lần lượt nói từng câu của một đoạn `PED_CONVO_k_1..` (mỗi đoạn 2-3 câu), rồi ai đi đường nấy.

const TICK := 3.0
const START_CHANCE := 0.5
const NEAR_PLAYER := 420.0
const PAIR_DIST := 96.0
const LINE_GAP := 2.3  # giây giữa hai câu liên tiếp
const TAIL := 1.2  # giây đứng thêm sau câu cuối

var city: City
var _timer := TICK
var _busy := false


func _init(c: City) -> void:
	city = c
	name = "PedChatter"


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or _busy:
		return
	_timer = TICK
	if randf() < START_CHANCE:
		_start()


func _start() -> void:
	var near: Array[Pedestrian] = []
	for p in get_tree().get_nodes_in_group("peds"):
		if p is Pedestrian and p.is_idle() and p.global_position.distance_to(city.player.global_position) < NEAR_PLAYER:
			near.append(p)
	near.shuffle()
	for a in near:
		for b in near:
			if a != b and a.global_position.distance_to(b.global_position) < PAIR_DIST:
				_talk(a, b)
				return


func _talk(a: Pedestrian, b: Pedestrian) -> void:
	_busy = true
	var convo := "PED_CONVO_%d" % randi_range(1, Speech.count("PED_CONVO", "_1"))
	var lines := Speech.count(convo)
	var speakers := [a, b]
	for ped in speakers:
		ped.chat_with(speakers[1 - speakers.find(ped)], lines * LINE_GAP + TAIL)
	for i in lines:
		var who: Pedestrian = speakers[i % 2]
		if not is_instance_valid(who) or not who.can_chat():
			break
		var other: Pedestrian = speakers[1 - i % 2]
		if is_instance_valid(other):
			Speech.clear(other)
		Speech.say(who, "%s_%d" % [convo, i + 1])
		await get_tree().create_timer(LINE_GAP, false).timeout
		if not is_inside_tree():
			return
	_busy = false
