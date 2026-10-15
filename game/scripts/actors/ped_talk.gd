class_name PedTalk
extends Object
## Bắt chuyện với người đi đường (phím tương tác khi đứng cạnh): câu chào, tin đồn, mẹo chơi. Thỉnh thoảng có người
## nhờ tìm đồ đánh rơi gần đó (việc vặt, xem activity_errand.gd).

const RADIUS := 56.0
const ERRAND_CHANCE := 0.3
const LINES := ["PED_HELLO_1", "PED_HELLO_2", "PED_HELLO_3", "PED_HELLO_4", "PED_RUMOR_1", "PED_RUMOR_2", "PED_RUMOR_3", "PED_RUMOR_4",
	"PED_TIP_RESPRAY", "PED_TIP_HOSPITAL", "PED_TIP_RACE", "PED_TIP_COINS", "PED_TIP_BUSINESS", "PED_TIP_TAXI"]


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
		Speech.say(ped, LINES.pick_random())
