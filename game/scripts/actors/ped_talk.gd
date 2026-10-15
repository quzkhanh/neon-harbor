class_name PedTalk
extends Object
## Bắt chuyện với người đi đường (phím tương tác khi đứng cạnh): câu chào, tin đồn, mẹo chơi. Thỉnh thoảng có người
## nhờ tìm đồ đánh rơi gần đó (việc vặt, xem activity_errand.gd).

const RADIUS := 56.0
const ERRAND_CHANCE := 0.3
const TIPS := ["PED_TIP_RESPRAY", "PED_TIP_HOSPITAL", "PED_TIP_RACE", "PED_TIP_COINS", "PED_TIP_BUSINESS", "PED_TIP_TAXI"]
const CONTEXT_CHANCE := 0.5  # gặp hoàn cảnh hợp (mưa, đêm, đang bị truy nã) thì bấy nhiêu khả năng nói về nó
const QUIRK_LINES := {"robot": "PED_ROBOT", "feeder": "PED_FEEDER", "drunk": "PED_DRUNK", "nightshift": "PED_NIGHTSHIFT", "loiter": "PED_LOITER"}
const QUIRK_CHANCE := 0.75  # người kỳ dị hầu như luôn nói kiểu của mình


## Người đi đường gần Jay nhất mà đang rảnh để nói chuyện, hoặc null.
static func nearest(city: City) -> Pedestrian:
	var best: Pedestrian = null
	var best_d := RADIUS
	for p in city.get_tree().get_nodes_in_group("peds"):
		var d: float = p.global_position.distance_to(city.player.global_position)
		if d < best_d and p.can_chat():
			best = p
			best_d = d
	return best


static func talk(ped: Pedestrian, city: City) -> void:
	ped.chat()
	if randf() < ERRAND_CHANCE and not city.activities.busy():
		Speech.say(ped, "PED_ERRAND_ASK")
		city.activities.start("errand", 0, ped)
	else:
		Speech.say(ped, _line(city, ped))


## Nhóm câu theo tiếng tăm của Jay (từ bậc 2): được mến thì chào thân thiện, đáng sợ thì run.
static func _fame_topics() -> Array:
	var out := []
	if Game.fame.tier("goodwill") >= 2:
		out.append("PED_FRIEND")
	if Game.fame.tier("notoriety") >= 2:
		out.append("PED_FEAR")
	return out


## Câu hợp hoàn cảnh (đang bị truy nã, trời mưa, ban đêm) hoặc câu chào/tin đồn/mẹo thường.
static func _line(city: City, ped: Pedestrian) -> String:
	if ped.quirk != "" and randf() < QUIRK_CHANCE:
		return Speech.pick(QUIRK_LINES[ped.quirk])
	var topics := []
	var weather: Weather = city.get_node_or_null("Weather")
	if Game.stars > 0:
		topics.append("PED_COPS")
	if randf() < Tuning.FAME_CHAT_CHANCE:
		topics.append_array(_fame_topics())
	if weather and weather.raining:
		topics.append("PED_RAIN")
	if Game.is_night():
		topics.append("PED_NIGHT")
	if not topics.is_empty() and randf() < CONTEXT_CHANCE:
		return Speech.pick(topics.pick_random())
	var roll := randi() % 3
	return TIPS.pick_random() if roll == 0 else Speech.pick("PED_HELLO" if roll == 1 else "PED_RUMOR")
