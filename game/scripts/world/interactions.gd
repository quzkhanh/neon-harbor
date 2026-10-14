class_name Interactions
extends Node
## Tìm hành động khả dụng quanh người chơi (lên/xuống xe, bán xe ở gara), hiện gợi ý trên HUD,
## thực hiện khi bấm `interact`. Đi vào cửa hàng thì tự mở giao diện cửa hàng.

const GARAGE_RADIUS := 120.0
const DOOR_RADIUS := 34.0

var city: City
var prompt := ""
var prompt_params := {}
var _action := Callable()
var _shop_armed := true
var _shop_pos: Vector2
var _garage_pos: Vector2


func _init(c: City) -> void:
	city = c
	name = "Interactions"


func _ready() -> void:
	_shop_pos = MapData.cell_center(city.data.find("S"))
	_garage_pos = MapData.cell_center(city.data.find("G"))
	for sign_def in [["S", "SIGN_SHOP", Palette.CYAN], ["H", "SIGN_HOSPITAL", Palette.HEALTH], ["G", "SIGN_GARAGE", Palette.GOLD]]:
		var pos := MapData.cell_center(city.data.find(sign_def[0]))
		SignPost.make(city.effects, pos, sign_def[2], sign_def[1])


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
		else:
			_set_prompt("HINT_EXIT", p.exit_vehicle)
		return
	var near_shop := p.global_position.distance_to(_shop_pos) < DOOR_RADIUS
	if near_shop and _shop_armed:
		_shop_armed = false
		city.overlays.show_shop()
	elif not near_shop:
		_shop_armed = true
	var v := nearest_vehicle()
	if v:
		_set_prompt("HINT_ENTER", _enter.bind(v))


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
		if not v.wrecked and not v.burning and d < best_d:
			best = v
			best_d = d
	return best


## Lên xe; nếu có người lái thì kéo họ ra (cảnh sát thấy thì tính là cướp xe).
func _enter(v: Vehicle) -> void:
	if v.has_npc_driver:
		var ped := city.spawn_npc(Pedestrian, v.exit_point())
		ped.add_to_group("peds")
		ped.flee(city.player.global_position)
		for c in city.police.cops():
			if c.alive and c.can_see(v.global_position, Tuning.COP_SIGHT):
				Game.add_heat(Tuning.HEAT_CARJACK_SEEN)
				break
	city.player.enter_vehicle(v)


func sell_price(v: Vehicle) -> int:
	if v.has_meta("mission"):
		return 0
	var base: int = Tuning.CAR_SELL_PRICE.get(v.kind, 0)
	return int(base * clampf(v.hp / float(v.spec.hp), 0.3, 1.0))


func _sell(v: Vehicle) -> void:
	var price := sell_price(v)
	city.player.exit_vehicle()
	Game.add_money(price)
	Game.save_game()
	Sfx.play("cash")
	Game.notice.emit(I18n.fmt("NOTICE_SOLD", {"price": I18n.money(price)}))
	v.queue_free()
