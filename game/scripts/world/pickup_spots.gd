class_name PickupSpots
extends Node
## Hộp máu ("h"), áo giáp ("a") và huy hiệu hối lộ ("W", chỉ nhặt khi đang bị truy nã: giảm 1 sao) cố định trên
## bản đồ; nhặt rồi thì một lúc sau mới có lại. Xu neon ("o") chỉ nhặt một lần (lưu trong save).

var city: City


func _init(c: City) -> void:
	city = c
	name = "PickupSpots"


func _ready() -> void:
	for cell in city.data.find_all("h"):
		_spawn(MapData.cell_center(cell), true)
	for cell in city.data.find_all("a"):
		_spawn(MapData.cell_center(cell), false)
	for cell in city.data.find_all("W"):
		_spawn_badge(MapData.cell_center(cell))
	var tokens := city.data.find_all("o")
	for cell in tokens:
		var id := "%d,%d" % [cell.x, cell.y]
		if not Game.marked("tokens").has(id):
			Pickup.make(city.effects, MapData.cell_center(cell), "token", false).collected.connect(_on_token.bind(id, tokens.size()))


func _spawn(pos: Vector2, health: bool) -> void:
	var p := Pickup.spawn_health(city.effects, pos, Tuning.MEDKIT_PICKUP, false) if health \
		else Pickup.spawn_armor(city.effects, pos, Tuning.ARMOR_PICKUP, false)
	p.collected.connect(func() -> void:
		get_tree().create_timer(Tuning.PICKUP_RESPAWN).timeout.connect(_spawn.bind(pos, health)))


func _spawn_badge(pos: Vector2) -> void:
	var p := Pickup.make(city.effects, pos, "badge", false)
	p.can_take = func() -> bool: return Game.stars > 0
	p.collected.connect(func() -> void:
		Game.lose_star()
		Sfx.play("pickup")
		Game.notice.emit(tr("NOTICE_BRIBE"))
		get_tree().create_timer(Tuning.BADGE_RESPAWN).timeout.connect(_spawn_badge.bind(pos)))


func _on_token(id: String, total: int) -> void:
	Game.mark("tokens", id)
	Game.add_money(Tuning.TOKEN_VALUE)
	Sfx.play("checkpoint")
	var got := Game.marked("tokens").size()
	Game.notice.emit(I18n.fmt("NOTICE_TOKEN", {"got": got, "total": total}))
	if got == total:
		Game.add_money(Tuning.TOKEN_ALL_BONUS)
		Game.notice.emit(I18n.fmt("NOTICE_TOKENS_ALL", {"money": I18n.money(Tuning.TOKEN_ALL_BONUS)}))
