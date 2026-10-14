class_name Tutorial
extends CanvasLayer
## Hướng dẫn người chơi mới: từng bước một (đi, bắn, bản đồ, nhận nhiệm vụ, lên xe, lái, mua súng),
## mỗi bước tự qua khi người chơi làm được; bước tuỳ chọn tự qua sau một lúc; người chơi làm vượt lên
## (đã nhận nhiệm vụ, đã lên xe) thì nhảy tới bước tương ứng. Xong thì tắt (bật lại ở Cài đặt).

const BOTTOM := 130
const WALK_DIST := 160.0
const DRIVE_DIST := 700.0
const LAST_STEP_TIME := 9.0
const OPTIONAL_STEP_TIME := 20.0
const FIRST_REQUIRED := 3  # từ bước nhận nhiệm vụ trở đi: điều kiện là trạng thái, dùng để nhảy cóc

var city: City
var _steps: Array = []
var _index := 0
var _label: LiveLabel
var _origin := Vector2.ZERO
var _timer := 0.0
var _map_seen := false


func _init(c: City) -> void:
	city = c
	name = "Tutorial"
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS  # để thấy được lúc bản đồ (đang tạm dừng game) mở


static func wanted() -> bool:
	return Game.settings.get("tutorial", true)


func _ready() -> void:
	# [khoá dịch, tên action để hiện phím (hoặc ""), điều kiện xong]
	_steps = [
		["TUT_MOVE", &"", func() -> bool: return _moved(WALK_DIST)],
		["TUT_SHOOT", &"", func() -> bool: return Input.is_action_pressed("fire")],
		["TUT_MAP", &"map", func() -> bool: return _map_seen],
		["TUT_MISSION", &"", func() -> bool: return city.missions.current != null],
		["TUT_VEHICLE", &"interact", func() -> bool: return city.player.vehicle != null],
		["TUT_DRIVE", &"handbrake", func() -> bool: return _moved(DRIVE_DIST)],
		["TUT_SHOP", &"map", func() -> bool: return _timer > LAST_STEP_TIME],
	]
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("margin_bottom", BOTTOM)
	add_child(root)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "HudPanel"
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var box := Ui.vbox(2)
	panel.add_child(box)
	box.add_child(Ui.label("TUT_TITLE", "SmallLabel"))
	_label = Ui.live_label("", _params, "HintLabel")
	box.add_child(_label)
	_show(0)


func _params() -> Dictionary:
	var action: StringName = _steps[_index][1]
	return {"key": InputSetup.key_label(action) if action != &"" else ""}


func _process(delta: float) -> void:
	if city.overlays.current is MapScreen:
		_map_seen = true
	if get_tree().paused or not city.player.alive:
		return
	_timer += delta
	var next := _index + 1 if _steps[_index][2].call() or (_index < FIRST_REQUIRED and _timer > OPTIONAL_STEP_TIME) else _index
	for j in range(maxi(_index + 1, FIRST_REQUIRED), _steps.size() - 2):
		if _steps[j][2].call():
			next = j + 1
	if next >= _steps.size():
		Game.set_setting("tutorial", false)
		queue_free()
	elif next != _index:
		_show(next)


func _show(i: int) -> void:
	_index = i
	_timer = 0.0
	_origin = _position()
	_label.setup(_steps[i][0])
	Sfx.play("pickup", -6.0)


func _position() -> Vector2:
	var p := city.player
	return p.vehicle.global_position if p.vehicle else p.global_position


func _moved(dist: float) -> bool:
	return _position().distance_to(_origin) > dist
