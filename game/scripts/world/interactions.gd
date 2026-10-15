class_name Interactions
extends Node
## Tìm hành động khả dụng quanh người chơi (lên/xuống xe, bán xe ở gara, sửa + sơn xe để xoá truy nã),
## hiện gợi ý trên HUD, thực hiện khi bấm `interact`. Đi vào cửa hàng thì tự mở giao diện cửa hàng;
## đi vào cửa bệnh viện thì được chữa đầy máu miễn phí.

const GARAGE_RADIUS := 120.0
const DOOR_RADIUS := 34.0
const SIGNS := [["S", "SIGN_SHOP", Palette.CYAN, MapIcon.Kind.SHOP], ["H", "SIGN_HOSPITAL", Palette.HEALTH, MapIcon.Kind.HOSPITAL],
	["G", "SIGN_GARAGE", Palette.GOLD, MapIcon.Kind.GARAGE], ["R", "SIGN_RESPRAY", Palette.ACCENT, MapIcon.Kind.RESPRAY]]

var city: City
var prompt := ""
var prompt_params := {}
var _action := Callable()
var _shop_armed := true
var _shops: Array[Vector2] = []
var _hospitals: Array[Vector2] = []
var _resprays: Array[Vector2] = []
var _garage_pos: Vector2


func _init(c: City) -> void:
	city = c
	name = "Interactions"


func _ready() -> void:
	_shops = _spots("S")
	_resprays = _spots("R")
	_hospitals = _spots("H")
	_garage_pos = MapData.cell_center(city.data.find("G"))
	for sign_def in SIGNS:
		for pos in _spots(sign_def[0]):
			SignPost.make(city.effects, pos, sign_def[2], sign_def[1], sign_def[3])


func _spots(ch: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for cell in city.data.find_all(ch):
		out.append(MapData.cell_center(cell))
	return out


func _near(pos: Vector2, spots: Array[Vector2], radius: float) -> bool:
	return spots.any(func(s: Vector2) -> bool: return pos.distance_to(s) < radius)


func _process(_delta: float) -> void:
	var p := city.player
	_set_prompt("", Callable())
	if not p.alive or get_tree().paused:
		return
	if p.vehicle:
		var v := p.vehicle
		var price := sell_price(v)
		if price > 0 and v.global_position.distance_to(_garage_pos) < GARAGE_RADIUS:
			_set_prompt("HINT_SELL", _sell.bind(v), {"price": I18n.money(price)})
		elif _needs_shop(v) and _near(v.global_position, _resprays, GARAGE_RADIUS):
			_set_prompt("HINT_RESPRAY", _respray.bind(v), {"price": I18n.money(Tuning.RESPRAY_PRICE)})
		elif not _job_prompt():
			_set_prompt("HINT_EXIT", p.exit_vehicle)
		return
	if Game.health < Tuning.MAX_HEALTH and _near(p.global_position, _hospitals, DOOR_RADIUS):
		Game.heal(Tuning.MAX_HEALTH)
		Sfx.play("pickup")
		Game.notice.emit(tr("NOTICE_HOSPITAL_HEAL"))
	var near_shop := _near(p.global_position, _shops, DOOR_RADIUS)
	if near_shop and _shop_armed:
		_shop_armed = false
		city.overlays.show_shop()
	elif not near_shop:
		_shop_armed = true
	if _job_prompt():
		return
	var v := nearest_vehicle()
	if v:
		_set_prompt("HINT_ENTER", _enter.bind(v))


## Điểm bắt đầu việc phụ (đua xe, giao hàng, càn quét) hoặc cửa nhà an toàn / cơ sở kinh doanh ở gần.
func _job_prompt() -> bool:
	var job := city.activities.prompt()
	if job.is_empty():
		job = city.properties.prompt()
	if job.is_empty():
		return false
	_set_prompt(job[0], job[1], job[2] if job.size() > 2 else {})
	return true


func _set_prompt(key: String, action: Callable, params := {}) -> void:
	prompt = key
	prompt_params = params
	_action = action


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _action.is_valid() and city.player.controls_enabled:
		get_viewport().set_input_as_handled()
		_action.call()


func nearest_vehicle() -> Vehicle:
	var best: Vehicle = null
	var best_d := Tuning.INTERACT_RADIUS
	for v in get_tree().get_nodes_in_group("vehicles"):
		var d: float = v.global_position.distance_to(city.player.global_position) - v.size.y * 0.5
		var scripted: bool = v.has_meta("mission") and v.has_npc_driver  # xe nhiệm vụ do NPC lái (đối thủ đua, xe đưa tin...)
		if not v.wrecked and not v.burning and not scripted and d < best_d:
			best = v
			best_d = d
	return best


## Lên xe; nếu có người lái thì kéo họ ra (cảnh sát thấy thì tính là cướp xe).
func _enter(v: Vehicle) -> void:
	if v.has_npc_driver:
		var ped := city.spawn_npc(Pedestrian, v.exit_point())
		ped.add_to_group("peds")
		if randf() < Tuning.CARJACK_FIGHT_CHANCE:
			ped.provoke()
		else:
			ped.flee(city.player.global_position)
		for c in city.police.cops():
			if c.alive and c.can_see(v.global_position, Tuning.COP_SIGHT):
				Game.add_heat(Tuning.HEAT_CARJACK_SEEN)
				break
	city.player.enter_vehicle(v)


func sell_price(v: Vehicle) -> int:
	if v.has_meta("mission"):
		return 0
	var base := int(v.spec.get("sell", 0))
	return int(base * clampf(v.hp / float(v.spec.hp), 0.3, 1.0))


func _sell(v: Vehicle) -> void:
	if v.has_meta("garage"):  # xe lấy từ gara nhà an toàn: bán rồi thì gara trống
		Game.stats.erase("garage_%d" % v.get_meta("garage"))
	var price := sell_price(v)
	city.player.exit_vehicle()
	Game.add_money(price)
	Game.save_game()
	Sfx.play("cash")
	Game.notice.emit(I18n.fmt("NOTICE_SOLD", {"price": I18n.money(price)}))
	v.queue_free()


func _needs_shop(v: Vehicle) -> bool:
	return Game.stars > 0 or v.flat or v.hp < float(v.spec.hp)


## Tiệm sửa và sơn xe: trả tiền, xe đầy máu, vá lốp, đổi màu; cảnh sát mất dấu (xoá truy nã).
func _respray(v: Vehicle) -> void:
	if not Game.spend(Tuning.RESPRAY_PRICE):
		return
	var wanted := Game.stars > 0
	v.repair()
	v.repaint()
	Game.clear_wanted()
	Sfx.play("cash")
	Game.notice.emit(tr("NOTICE_RESPRAYED" if wanted else "NOTICE_REPAIRED"))
