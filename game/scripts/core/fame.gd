class_name Fame
extends RefCounted
## Tiếng tăm: Thiện cảm (giúp người) và Uy danh (gây sợ), mỗi cái 0..Tuning.FAME_MAX, chia bậc 0..5 theo Tuning.FAME_TIERS.
## Mọi nguồn chỉ gọi `Game.deed(id)`; bảng điểm theo việc nằm ở Tuning.FAME_DEEDS. Uy danh tự giảm dần, Thiện cảm thì không.

signal tier_changed(kind: String, tier: int)

const KINDS := ["goodwill", "notoriety"]
const KEYS := {"goodwill": "FAME_GOODWILL", "notoriety": "FAME_NOTORIETY"}  # tên chỉ số
const TIER_KEYS := {"goodwill": "FAME_GOODWILL_TIER", "notoriety": "FAME_NOTORIETY_TIER"}  # nhóm khoá tên bậc `_1..6` (bậc 0..5)

var value := {"goodwill": 0.0, "notoriety": 0.0}


func deed(id: String) -> void:
	var points: Array = Tuning.FAME_DEEDS[id]
	for i in KINDS.size():
		_add(KINDS[i], points[i])


## Uy danh giảm theo thời gian chơi (Achievements gọi mỗi giây).
func decay(seconds: float) -> void:
	_add("notoriety", -Tuning.FAME_DECAY * seconds)


func tier(kind: String) -> int:
	return Tuning.FAME_TIERS.filter(func(t: float) -> bool: return value[kind] >= t).size()


## Khoá dịch tên bậc `t` của chỉ số `kind`.
func tier_key(kind: String, t: int) -> String:
	return "%s_%d" % [TIER_KEYS[kind], t + 1]


func reset() -> void:
	value = {"goodwill": 0.0, "notoriety": 0.0}


func to_dict() -> Dictionary:
	return value.duplicate()


func load_dict(d: Dictionary) -> void:
	reset()
	for kind in KINDS:
		value[kind] = clampf(float(d.get(kind, 0.0)), 0.0, Tuning.FAME_MAX)


func _add(kind: String, amount: float) -> void:
	if amount == 0.0:
		return
	var before := tier(kind)
	value[kind] = clampf(value[kind] + amount, 0.0, Tuning.FAME_MAX)
	var after := tier(kind)
	if after != before:
		tier_changed.emit(kind, after)
