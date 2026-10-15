class_name Achievements
extends Node
## Thành tựu và thống kê: mỗi giây ghi thời gian chơi, quãng đường, rồi xét các thành tựu (đạt thì báo + lưu).
## Điều kiện đọc từ Game.stats; % hoàn thành gộp đều từ các nhóm việc của thành phố.

const LIST := {  # id: [chỉ số, mức cần đạt, khoá tên]
	"first_blood": ["kills", 1, "ACH_FIRST_BLOOD"], "five_stars": ["max_stars", 5, "ACH_FIVE_STARS"],
	"story": ["missions", 9, "ACH_STORY"], "collector": ["tokens", 40, "ACH_COLLECTOR"],
	"stuntman": ["jump_ids", 8, "ACH_STUNTMAN"], "street_king": ["races_won_ids", 3, "ACH_STREET_KING"],
	"landlord": ["safehouses", 3, "ACH_LANDLORD"], "tycoon": ["businesses", 4, "ACH_TYCOON"],
	"cabbie": ["fares", 10, "ACH_CABBIE"], "vigilante": ["criminals", 10, "ACH_VIGILANTE"],
	"courier": ["delivery_chains", 1, "ACH_COURIER"], "nitro": ["nitro_s", 60, "ACH_NITRO"],
}

var city: City
var _timer := 0.0
var _walk := 0.0
var _drive := 0.0
var _last := Vector2.INF


func _init(c: City) -> void:
	city = c
	name = "Achievements"


func _process(delta: float) -> void:
	var p := city.player
	var pos := p.global_position
	if _last != Vector2.INF and p.alive and pos.distance_to(_last) < Tuning.TILE * 4.0:  # bỏ qua dịch chuyển (hồi sinh)
		if p.vehicle:
			_drive += pos.distance_to(_last)
		else:
			_walk += pos.distance_to(_last)
	_last = pos
	_timer += delta
	if _timer < Tuning.STATS_FLUSH:
		return
	Game.bump("play_s", roundi(_timer))
	Game.bump("walk_px", roundi(_walk))
	Game.bump("drive_px", roundi(_drive))
	_timer = 0.0
	_walk = 0.0
	_drive = 0.0
	check()


## Giá trị hiện tại của một chỉ số (bộ đếm hoặc số phần tử của tập).
static func value(key: String) -> int:
	if key == "missions":
		return Game.missions_done.size()
	var v: Variant = Game.stats.get(key, 0)
	return v.size() if v is Array else int(v)


func check() -> void:
	if Game.stat("cheated") > 0:
		return
	for id in LIST:
		if value(LIST[id][0]) >= int(LIST[id][1]) and Game.mark("achievements", id):
			Sfx.play("achievement")
			Game.notice.emit(I18n.fmt("NOTICE_ACHIEVEMENT", {"name": tr(LIST[id][2])}))


## Phần trăm hoàn thành thành phố (0..100).
static func completion() -> int:
	var parts := 0.0
	for id in LIST:
		parts += minf(float(value(LIST[id][0])) / float(LIST[id][1]), 1.0)
	return roundi(parts / LIST.size() * 100.0)
