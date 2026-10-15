class_name Properties
extends Node
## Nhà an toàn (Z) và cơ sở kinh doanh (B), mua ở cửa. Nhà an toàn: nghỉ (đầy máu, lưu game), thuê đàn em, thay đồ,
## gara một chỗ (lái xe tới cửa rồi cất: xe được giữ qua lần lưu/nạp). Cơ sở kinh doanh trả thu nhập mỗi nửa đêm.

const BUSINESS_NAMES := ["BUSINESS_CAR_WASH", "BUSINESS_CLUB", "BUSINESS_DINER", "BUSINESS_DOCKS"]
const DOOR_RADIUS := 40.0
const GARAGE_RADIUS := 170.0

var city: City
var safehouses: Array[Vector2] = []
var businesses: Array[Vector2] = []
var _hour := -1


func _init(c: City) -> void:
	city = c
	name = "Properties"


func _ready() -> void:
	for cell in city.data.find_all("Z"):
		safehouses.append(MapData.cell_center(cell))
	for cell in city.data.find_all("B"):
		businesses.append(MapData.cell_center(cell))
	for pos in safehouses:
		SignPost.make(city.effects, pos, Palette.MONEY, "SIGN_SAFEHOUSE", MapIcon.Kind.SAFEHOUSE)
	for i in businesses.size():
		SignPost.make(city.effects, businesses[i], Palette.ICON_BUSINESS, BUSINESS_NAMES[i % BUSINESS_NAMES.size()], MapIcon.Kind.BUSINESS)
	for i in safehouses.size():
		var stored: Dictionary = Game.stats.get("garage_%d" % i, {})
		if owns("safehouses", i) and not stored.is_empty() and DataDB.vehicles().has(stored.kind):
			var v := city.spawn_vehicle(stored.kind, MapData.world_to_cell(safehouses[i]), 0.0, stored.sprite)
			v.global_position = _garage_spot(i)
			v.set_meta("garage", i)


func owns(kind: String, i: int) -> bool:
	return Game.marked(kind).has(str(i))


## Ô đỗ xe của gara: trên đường gần cửa nhà an toàn nhất.
func _garage_spot(i: int) -> Vector2:
	var c0 := MapData.world_to_cell(safehouses[i])
	for r in range(1, 6):
		for d in [Vector2i(0, r), Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, -r)]:
			if city.data.is_road(c0 + d) or city.data.at(c0 + d) == "-":
				return MapData.cell_center(c0 + d)
	return safehouses[i] + Vector2(0, Tuning.TILE)


func _process(_delta: float) -> void:
	var hour := int(Game.clock)
	if _hour == 23 and hour == 0:
		_pay_income()
	_hour = hour


func income() -> int:
	var total := 0
	for i in businesses.size():
		if owns("businesses", i):
			total += int(Tuning.BUSINESS_INCOME[i])
	return total


func _pay_income() -> void:
	var total := income()
	if total > 0:
		Game.add_money(total)
		Sfx.play("cash")
		Game.notice.emit(I18n.fmt("NOTICE_INCOME", {"money": I18n.money(total)}))


## Gợi ý + hành động ở cửa nhà an toàn / cơ sở kinh doanh (Interactions gọi): [khoá, Callable, tham số] hoặc [].
func prompt() -> Array:
	var p := city.player
	if p.vehicle:
		for i in safehouses.size():
			if owns("safehouses", i) and not p.vehicle.has_meta("mission") and p.vehicle.global_position.distance_to(safehouses[i]) < GARAGE_RADIUS:
				return ["HINT_STORE_CAR", _store.bind(i, p.vehicle), {}]
		return []
	for i in safehouses.size():
		if p.global_position.distance_to(safehouses[i]) < DOOR_RADIUS:
			if owns("safehouses", i):
				return ["HINT_SAFEHOUSE", _open_safehouse, {}]
			return ["HINT_BUY_SAFEHOUSE", _buy.bind("safehouses", i, int(Tuning.SAFEHOUSE_PRICES[i])), {"price": I18n.money(int(Tuning.SAFEHOUSE_PRICES[i]))}]
	for i in businesses.size():
		if p.global_position.distance_to(businesses[i]) < DOOR_RADIUS:
			if owns("businesses", i):
				return ["HINT_BUSINESS_OWNED", func() -> void: pass, {"money": I18n.money(int(Tuning.BUSINESS_INCOME[i]))}]
			return ["HINT_BUY_BUSINESS", _buy.bind("businesses", i, int(Tuning.BUSINESS_PRICES[i])), {"price": I18n.money(int(Tuning.BUSINESS_PRICES[i])),
				"money": I18n.money(int(Tuning.BUSINESS_INCOME[i]))}]
	return []


func _buy(kind: String, i: int, price: int) -> void:
	if not Game.spend(price):
		return
	Game.mark(kind, str(i))
	Game.save_game()
	Sfx.play("cash")
	Game.notice.emit(tr("NOTICE_BOUGHT_SAFEHOUSE" if kind == "safehouses" else "NOTICE_BOUGHT_BUSINESS"))


func _store(i: int, v: Vehicle) -> void:
	if v.has_meta("garage"):  # xe dời từ gara khác sang: gara cũ trống
		Game.stats.erase("garage_%d" % v.get_meta("garage"))
	Game.stats["garage_%d" % i] = {"kind": v.kind, "sprite": v.sprite_name}
	v.set_meta("garage", i)
	city.player.exit_vehicle()
	Game.save_game()
	Game.notice.emit(tr("NOTICE_CAR_STORED"))


func _open_safehouse() -> void:
	var choice: Variant = await city.overlays.open(SafehouseMenu.new())
	match choice:
		"rest":
			Game.heal(Tuning.MAX_HEALTH)
			Game.save_game()
			Sfx.play("pickup")
			Game.notice.emit(tr("NOTICE_RESTED"))
		"hire":
			if get_tree().get_nodes_in_group("allies").size() >= Tuning.ALLY_MAX:
				Game.notice.emit(tr("NOTICE_ALLY_FULL"))
			elif Game.spend(Tuning.ALLY_PRICE):
				city.spawn_npc(Ally, city.player.global_position + Vector2(40, 40))
				Sfx.play("cash")
				Game.notice.emit(tr("NOTICE_ALLY_HIRED"))
		"outfit":
			await city.overlays.open(Wardrobe.new())
