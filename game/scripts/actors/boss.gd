class_name Boss
extends Gangster
## Silas Crane, trùm Red Fangs (NV9): máu rất cao, súng trường, nhuộm đỏ cho khác đàn em.


func _ready() -> void:
	super()
	skin = "manOld"
	set_pose("machine")
	max_health = Tuning.BOSS_HEALTH
	health = max_health
	gun = Gun.new(DataDB.weapon("rifle"))
	body.modulate = Palette.BOSS_TINT
	add_to_group("boss")


## Chỉ xe do Jay lái mới tông ngã được trùm (xe chạy qua cửa kho không được "giết hộ").
func knock_down(dir: Vector2, damage: float, source: Variant) -> void:
	if source is Player:
		super(dir, damage, source)
