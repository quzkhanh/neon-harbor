class_name WeaponWheel
extends CanvasLayer
## Vòng chọn súng: giữ phím đổi súng (Q / RB / nút Đổi súng) thì hiện các súng đang có quanh tâm màn hình,
## thời gian chậm lại; hướng chuột / analog / phím di chuyển chọn ô, nhả phím để cầm. Chạm thẳng vào ô cũng chọn.

const ICON := "res://assets/sprites/weapons/icon_%s.png"
const RADIUS := 210.0
const CELL := Vector2(150, 84)
const DEAD := 40.0  # chuột chưa ra khỏi vùng giữa thì giữ ô đang chọn

var _ids: Array = []
var _cells: Array[Button] = []
var _index := 0
var _center := Vector2.ZERO


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = Tuning.WHEEL_SLOWMO
	_ids = Game.owned_ids()
	_index = maxi(_ids.find(Game.current), 0)
	var dim := ColorRect.new()
	dim.color = Palette.DIM_SCREEN
	dim.color.a = 0.35
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_center = get_viewport().get_visible_rect().size * 0.5
	for i in _ids.size():
		var b := Button.new()
		b.theme_type_variation = "TouchButton"
		b.focus_mode = Control.FOCUS_NONE
		b.icon = load(ICON % _ids[i])
		b.expand_icon = true
		b.custom_minimum_size = CELL
		b.size = CELL
		b.position = _center + Vector2.from_angle(-PI * 0.5 + TAU * i / _ids.size()) * RADIUS - CELL * 0.5
		b.pressed.connect(func() -> void:
			_index = i
			pick())
		add_child(b)
		_cells.append(b)
	_highlight()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(_delta: float) -> void:
	if get_tree().paused or Game.health <= 0.0:
		queue_free()
		return
	var dir := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if dir.length() < 0.3:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length() < 0.3:
		var mouse := get_viewport().get_mouse_position() - _center
		dir = mouse if mouse.length() > DEAD else Vector2.ZERO
	if dir != Vector2.ZERO and _ids.size() > 0:
		var step := TAU / _ids.size()
		_index = posmod(roundi(fposmod(dir.angle() + PI * 0.5, TAU) / step), _ids.size())
		_highlight()


func _highlight() -> void:
	for i in _cells.size():
		_cells[i].modulate = Color.WHITE if i == _index else Color(1, 1, 1, 0.55)
		_cells[i].scale = Vector2.ONE * (1.12 if i == _index else 1.0)
		_cells[i].pivot_offset = CELL * 0.5


## Cầm súng đang chọn và đóng vòng.
func pick() -> void:
	if _index < _ids.size():
		Game.select_weapon(_ids[_index])
	queue_free()
