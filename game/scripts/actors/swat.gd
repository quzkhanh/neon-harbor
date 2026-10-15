class_name Swat
extends Cop
## Đặc nhiệm NHPD (từ 4 sao): mũ giáp, súng trường, máu cao.


func _equip() -> void:
	skin = "robot1"
	max_health = Tuning.SWAT_HEALTH
	gun = Gun.new(DataDB.weapon(Tuning.SWAT_WEAPON))
