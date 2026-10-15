extends Node
## Autoload `Game`: nơi duy nhất giữ state (tiền, máu, súng, đạn, nhiệm vụ, truy nã, cài đặt),
## lưu/nạp save.json và chuyển cảnh.

signal money_changed(money: int)
signal vitals_changed
signal weapons_changed
signal wanted_changed(stars: int)
signal objective_changed
signal notice(text: String)
signal skin_changed

const MENU_SCENE := "res://scenes/menu.tscn"
const CITY_SCENE := "res://scenes/city.tscn"
const ENDING_SCENE := "res://scenes/ending.tscn"
const SAVE_PATH := "user://save.json"
const MISSIONS_PATH := "res://data/missions.json"
const AUDIO_SETTLE_MS := 200

var save_path := SAVE_PATH
var money := 0
var health := Tuning.MAX_HEALTH
var armor := 0.0
var owned := {}  # id súng -> {"mag": int}; đạn dự trữ luôn vô hạn
var current := "pistol"
var missions_done: Array = []
var objective := ""
var objective_params := {}
var heat := 0.0
var stars := 0
var settings := {"lang": "", "music": 0.7, "sfx": 0.8, "steering": "screen", "tutorial": true, "touch_scale": 1.0}
var skin := "hitman1"  # trang phục của Jay (tủ đồ nhà an toàn)
var fame := Fame.new()
var hair := Hair.STYLES[0]  # kiểu tóc của Jay (tủ đồ)
var hair_color := 0  # chỉ số trong Palette.HAIR
var god := false  # mã gian lận bất tử (không lưu)
var zombies := false  # mã gian lận đêm zombie (không lưu)
var clock := Tuning.START_HOUR  # giờ trong game (0..24), DayNight cho chạy
var stats := {}  # bộ đếm (số -> int) và tập đã đạt (khoá -> Array) cho việc phụ, sưu tầm, thống kê, thành tựu
var missions: Array = []

var _fade: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.register()
	missions = JSON.parse_string(FileAccess.get_file_as_string(MISSIONS_PATH))
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	UiTheme.install()
	reset_progress()
	load_game()
	fame.tier_changed.connect(_on_fame_tier)
	get_tree().auto_accept_quit = false
	var timer := Timer.new()
	timer.wait_time = Tuning.AUTOSAVE_INTERVAL
	timer.autostart = true
	timer.timeout.connect(_autosave)
	add_child(timer)


func _on_fame_tier(kind: String, tier: int) -> void:
	notice.emit(I18n.fmt("NOTICE_FAME", {"kind": tr(Fame.KEYS[kind]), "tier": tr(fame.tier_key(kind, tier))}))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_autosave()


## Trên Web, đóng tab không báo cho game: lưu định kỳ và khi chuyển tab/mất focus (chỉ khi đang chơi).
func _autosave() -> void:
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path == CITY_SCENE:
		save_game()


# --- Tiến trình và lưu game ---

func reset_progress() -> void:
	money = Tuning.START_MONEY
	health = Tuning.MAX_HEALTH
	armor = 0.0
	owned = {}
	_give_weapon("fists")
	_give_weapon("pistol")
	current = "pistol"
	missions_done = []
	stats = {}
	clock = Tuning.START_HOUR
	skin = Tuning.SKINS[0]
	hair = Hair.STYLES[0]
	hair_color = 0
	fame.reset()
	clear_objective()
	clear_wanted()


func has_progress() -> bool:
	return FileAccess.file_exists(save_path) and SaveIO.read(save_path).has("money")


func save_game() -> void:
	SaveIO.write(save_path, {
		"money": money, "owned": owned, "current": current,
		"missions_done": missions_done, "settings": settings, "stats": stats, "clock": clock, "skin": skin,
		"hair": hair, "hair_color": hair_color, "fame": fame.to_dict(),
	})


func load_game() -> void:
	var d := SaveIO.read(save_path)
	if d.has("settings"):
		settings.merge(d.settings, true)
	if d.has("money"):
		money = int(d.money)
		owned = {}
		for id in d.owned:
			if not DataDB.weapon(id).is_empty():
				owned[id] = {"mag": int(d.owned[id].mag)}
		for id in ["fists", "pistol"]:
			if not owned.has(id):
				_give_weapon(id)
		current = d.current if owned.has(d.current) else "pistol"
		missions_done = d.missions_done.map(func(n: Variant) -> int: return int(n))
		stats = d.get("stats", {})
		clock = float(d.get("clock", Tuning.START_HOUR))
		skin = d.get("skin", Tuning.SKINS[0]) if d.get("skin", "") in Tuning.SKINS else Tuning.SKINS[0]
		hair = d.get("hair", Hair.STYLES[0]) if d.get("hair", "") in Hair.STYLES else Hair.STYLES[0]
		hair_color = clampi(int(d.get("hair_color", 0)), 0, Palette.HAIR.size() - 1)
		fame.load_dict(d.get("fame", {}))
	apply_settings()


func apply_settings() -> void:
	I18n.set_language(settings.lang if settings.lang != "" else I18n.system_language())
	Sfx.set_volume("Music", settings.music)
	Sfx.set_volume("SFX", settings.sfx)


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	save_game()


func new_game() -> void:
	reset_progress()
	save_game()
	go(CITY_SCENE)


func continue_game() -> void:
	reset_progress()
	load_game()
	go(CITY_SCENE)


# --- Tiền và máu ---

func add_money(amount: int) -> void:
	money = maxi(money + amount, 0)
	money_changed.emit(money)


func spend(amount: int) -> bool:
	if money < amount:
		notice.emit(tr("SHOP_NOT_ENOUGH"))
		return false
	add_money(-amount)
	return true


## Giáp đỡ đòn trước. Trả về true nếu người chơi chết.
func damage_player(amount: float) -> bool:
	if god:
		return false
	var absorbed := minf(armor, amount)
	armor -= absorbed
	health = maxf(health - (amount - absorbed), 0.0)
	vitals_changed.emit()
	return health <= 0.0


func heal(amount: float) -> void:
	health = minf(health + amount, Tuning.MAX_HEALTH)
	vitals_changed.emit()


func add_armor(amount: float) -> void:
	armor = minf(armor + amount, Tuning.MAX_ARMOR)
	vitals_changed.emit()


## Hệ số giá theo Thiện cảm (1.0 = giá gốc).
func discount() -> float:
	return 1.0 - Tuning.FAME_DISCOUNT * fame.tier("goodwill")


## Giá sau khi giảm theo Thiện cảm (cửa hàng, tiệm sơn xe).
func price(base: int) -> int:
	return roundi(base * discount())


## Ghi một việc vừa làm vào tiếng tăm (id trong Tuning.FAME_DEEDS).
func deed(id: String) -> void:
	fame.deed(id)


## Trả phí hồi sinh theo tỉ lệ số tiền đang có. Trả về số tiền đã trả.
func pay_fee(rate: float) -> int:
	var fee := int(money * rate * discount())
	add_money(-fee)
	return fee


## Hồi sinh ở bệnh viện: mất 10% tiền, mất hết sao, giữ súng. Trả về số tiền viện phí.
func hospital_respawn() -> int:
	var fee := pay_fee(Tuning.DEATH_FEE)
	clear_wanted()
	revive()
	return fee


func revive() -> void:
	health = Tuning.MAX_HEALTH
	vitals_changed.emit()


# --- Thống kê và đồ sưu tầm ---

func bump(key: String, n := 1) -> void:
	stats[key] = stat(key) + n


func stat(key: String) -> int:
	return int(stats.get(key, 0))


func skin_unlocked(id: String) -> bool:
	return id != Tuning.SKINS[-1] or mission_count() in missions_done


## Đổi kiểu tóc và/hoặc màu tóc của Jay (tủ đồ).
func set_hair(style: String, color_index: int) -> void:
	hair = style
	hair_color = color_index
	skin_changed.emit()
	save_game()


func set_skin(id: String) -> void:
	if skin_unlocked(id):
		skin = id
		skin_changed.emit()
		save_game()


## Đánh dấu `id` đã đạt trong tập `key` (đồng xu, dốc nhảy...). Trả về true nếu là lần đầu.
func mark(key: String, id: Variant) -> bool:
	var got: Array = stats.get(key, [])
	if got.has(id):
		return false
	got.append(id)
	stats[key] = got
	return true


func marked(key: String) -> Array:
	return stats.get(key, [])


# --- Súng và đạn ---

func weapon_def(id := "") -> Dictionary:
	return DataDB.weapon(current if id == "" else id)


func ammo(id := "") -> Dictionary:
	return owned.get(current if id == "" else id, {"mag": 0})


func is_unlocked(id: String) -> bool:
	var need := int(weapon_def(id).unlock)
	return need == 0 or need in missions_done


func select_weapon(id: String) -> void:
	if owned.has(id) and id != current:
		current = id
		weapons_changed.emit()


func cycle_weapon(step: int) -> void:
	var ids := owned_ids()
	var i := ids.find(current)
	select_weapon(ids[posmod(i + step, ids.size())])


func owned_ids() -> Array:
	return DataDB.weapons().map(func(w: Dictionary) -> String: return w.id).filter(func(id: String) -> bool: return owned.has(id))


func consume_ammo() -> bool:
	var a: Dictionary = owned[current]
	if a.mag <= 0:
		return false
	a.mag -= 1
	weapons_changed.emit()
	return true


func can_reload() -> bool:
	return weapon_def().kind != "melee" and ammo().mag < int(weapon_def().mag)


func finish_reload() -> void:
	owned[current].mag = int(weapon_def().mag)
	weapons_changed.emit()


func buy_weapon(id: String) -> bool:
	if owned.has(id) or not is_unlocked(id) or not spend(price(int(weapon_def(id).price))):
		return false
	_give_weapon(id)
	select_weapon(id)
	save_game()
	return true


## Tặng súng (Rosa trang bị cho nhiệm vụ): cho súng với băng đầy và cầm luôn khẩu đó.
func grant_weapon(id: String) -> void:
	_give_weapon(id)
	select_weapon(id)


func _give_weapon(id: String) -> void:
	owned[id] = {"mag": int(weapon_def(id).mag)}
	weapons_changed.emit()


# --- Truy nã ---

func add_heat(amount: float) -> void:
	heat = minf(heat + amount, Tuning.MAX_HEAT)
	_update_stars()


func set_stars(n: int) -> void:
	heat = maxf(heat, Tuning.STAR_HEAT[n - 1])
	_update_stars()


func lose_star() -> void:
	heat = Tuning.STAR_HEAT[stars - 2] if stars >= 2 else 0.0
	_update_stars()


func is_night() -> bool:
	return clock >= Tuning.NIGHT_FROM or clock < Tuning.NIGHT_TO


func clear_wanted() -> void:
	heat = 0.0
	_update_stars()


func _update_stars() -> void:
	var n := Tuning.STAR_HEAT.filter(func(h: float) -> bool: return heat >= h).size()
	if n != stars:
		if n > stars:
			Sfx.play("star")
		stars = n
		stats["max_stars"] = maxi(stat("max_stars"), n)
		wanted_changed.emit(stars)


# --- Nhiệm vụ ---

func mission(n: int) -> Dictionary:
	return missions[n - 1]


func mission_count() -> int:
	return missions.size()


func next_mission() -> int:
	for n in range(1, mission_count() + 1):
		if not n in missions_done:
			return n
	return 0


func set_objective(key: String, params := {}) -> void:
	objective = key
	objective_params = params
	objective_changed.emit()


func clear_objective() -> void:
	set_objective("")


## Trả về danh sách id súng vừa được mở bán.
func complete_mission(n: int) -> Array:
	if n in missions_done:
		return []
	add_money(int(mission(n).reward))
	missions_done.append(n)
	clear_objective()
	save_game()
	return DataDB.weapons().filter(func(w: Dictionary) -> bool: return int(w.unlock) == n).map(func(w: Dictionary) -> String: return w.id)


# --- Chuyển cảnh và thoát ---

func go(scene: String) -> void:
	if _busy:
		return
	_busy = true
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, Tuning.FADE_TIME)
	await tween.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(scene)
	await get_tree().process_frame
	tween = create_tween()
	tween.tween_property(_fade, "modulate:a", 0.0, Tuning.FADE_TIME)
	_busy = false


## Hàm thoát duy nhất: lưu, tắt mọi âm thanh, chờ cho audio dừng hẳn rồi mới quit.
func quit(code := 0) -> void:
	save_game()
	get_tree().paused = true  # cảnh dừng hẳn: không nhân vật nào phát thêm tiếng trong lúc chờ
	Sfx.stop_all()
	Music.stop()
	await get_tree().create_timer(AUDIO_SETTLE_MS / 1000.0, true, false, true).timeout
	get_tree().quit(code)
