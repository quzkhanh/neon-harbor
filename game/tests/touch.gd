extends "res://tests/harness.gd"
## Điện thoại: chuột giả từ chạm không đổi hướng ngắm; hỗ trợ ngắm; joystick nổi và nút to; bắt xoay ngang.
## Chạy: godot --headless --path game -s res://tests/touch.gd


const AIM_ASSIST := "res://scripts/combat/aim_assist.gd"
const GANGSTER := "res://scripts/actors/gangster.gd"
const COP := "res://scripts/actors/cop.gd"
const PEDESTRIAN := "res://scripts/actors/pedestrian.gd"
const TILE := 64  # khớp Tuning.TILE
const RANGE := 650.0
const TOUCH_CONTROLS := "res://scripts/ui/touch_controls.gd"
const PHONE := Vector2i(915, 412)  # điện thoại cầm ngang (px CSS)
const MIN_TAP := 56.0  # cỡ chạm tối thiểu trên màn thật
const PORTRAIT := Vector2i(412, 915)
const INPUT_SETUP := "res://scripts/core/input_setup.gd"
const REACH := 360.0  # px canvas: tầm ngón cái từ nút BẮN tới các nút phụ
const PAUSE_CLEAR := 200.0  # px canvas: nút Tạm dừng cách xa mọi nút khác


func _run() -> void:
	var city := await open_city()
	await _check_emulated_mouse(city)
	await _check_aim_assist(city)
	await _check_touch_controls(city)
	await _check_rotate_guard()
	await _check_touch_hints()
	finish("TOUCH")


## Chạm sinh chuột giả (DEVICE_ID_EMULATION): không được coi là ngắm bằng chuột. Chuột thật thì có.
func _check_emulated_mouse(city: Node) -> void:
	var p: Node = city.player
	expect(await _aim_after_motion(p, InputEvent.DEVICE_ID_EMULATION) == 0.0, "chuột giả từ chạm làm đổi hướng ngắm")
	expect(await _aim_after_motion(p, 0) != 0.0, "đối chứng: chuột thật không đổi hướng ngắm")


func _aim_after_motion(p: Node, device: int) -> float:
	p._mouse_active_ms = -100000
	p.aim_angle = 0.0
	for i in 10:
		var e := InputEventMouseMotion.new()
		e.device = device
		e.position = Vector2(40, 40)
		e.relative = Vector2(5, 5)
		Input.parse_input_event(e)
		await physics(1)
	return p.aim_angle


## Hỗ trợ ngắm: chọn tên băng đảng trong nón, bỏ qua người đi đường, cảnh sát chỉ khi đang bị truy nã,
## ngoài nón hoặc sau tường thì không; người chơi dùng joystick thì được hút tâm.
func _check_aim_assist(city: Node) -> void:
	var assist: GDScript = load(AIM_ASSIST)
	var p: Node = city.player
	p.global_position = _open_spot(city)
	await physics(2)
	var o: Vector2 = p.global_position
	var ped := _spawn(city, PEDESTRIAN, o, 5.0, 150.0)
	expect(assist.pick(p, 0.0, RANGE) == 0.0, "hút tâm vào người đi đường")
	var gang := _spawn(city, GANGSTER, o, 15.0, 200.0)
	expect(_hits(assist.pick(p, 0.0, RANGE), o, gang), "không hút tâm vào tên băng đảng ở 15°")
	gang.global_position = o + Vector2.from_angle(deg_to_rad(40.0)) * 200.0
	expect(assist.pick(p, 0.0, RANGE) == 0.0, "hút tâm vào tên băng đảng ngoài nón (40°)")
	gang.global_position = o + Vector2.from_angle(deg_to_rad(15.0)) * 200.0
	Input.action_press(&"aim_right")
	await physics(2)
	expect(_hits(p.aim_angle, o, gang), "ngắm bằng joystick mà không được hút tâm (góc %.1f°)" % rad_to_deg(p.aim_angle))
	Input.action_release(&"aim_right")
	gang.queue_free()
	await physics(1)
	var cop := _spawn(city, COP, o, 10.0, 200.0)
	expect(assist.pick(p, 0.0, RANGE) == 0.0, "hút tâm vào cảnh sát khi không bị truy nã")
	game.set_stars(1)
	expect(_hits(assist.pick(p, 0.0, RANGE), o, cop), "không hút tâm vào cảnh sát khi đang bị truy nã")
	game.clear_wanted()
	cop.queue_free()
	ped.queue_free()
	var wall: Array = _wall_pair(city)
	p.global_position = wall[0]
	await physics(2)
	var hidden: Node = city.spawn_npc(load(GANGSTER), wall[1])
	var aim: float = (wall[1] - wall[0]).angle() + deg_to_rad(10.0)
	expect(assist.pick(p, aim, RANGE) == aim, "hút tâm xuyên tường")
	hidden.queue_free()
	await physics(2)


func _spawn(city: Node, script: String, o: Vector2, deg: float, dist: float) -> Node:
	return city.spawn_npc(load(script), o + Vector2.from_angle(deg_to_rad(deg)) * dist)


func _hits(angle: float, o: Vector2, target: Node) -> bool:
	return absf(angle_difference(angle, (target.global_position - o).angle())) < 0.01


## Ô trống rộng (không có ô đặc trong bán kính 5 ô) để đặt mục tiêu quanh người chơi.
func _open_spot(city: Node) -> Vector2:
	var data: Object = city.data
	for y in range(10, data.size.y - 10):
		for x in range(10, data.size.x - 10):
			var ok := true
			for dy in range(-5, 6):
				for dx in range(-5, 6):
					if data.is_solid(Vector2i(x + dx, y + dy)):
						ok = false
						break
				if not ok:
					break
			if ok:
				return Vector2(x, y) * TILE + Vector2.ONE * TILE * 0.5
	return Vector2.ZERO


## Hai ô đi được ở hai bên một khối nhà trên cùng một hàng, cách nhau trong tầm súng.
func _wall_pair(city: Node) -> Array:
	var data: Object = city.data
	for y in range(10, data.size.y - 10):
		for x in range(10, data.size.x - 20):
			var a := Vector2i(x, y)
			if not data.is_ped_walkable(a) or data.at(a + Vector2i.RIGHT) != "#":
				continue
			for w in range(2, 8):
				var b := a + Vector2i(w, 0)
				if data.is_ped_walkable(b):
					return [Vector2(a) * TILE + Vector2.ONE * TILE * 0.5, Vector2(b) * TILE + Vector2.ONE * TILE * 0.5]
				if data.at(b) != "#":
					break
	return [Vector2.ZERO, Vector2.ZERO]


## Ở khung 915×412: joystick nổi đặt dưới ngón tay, hai ngón độc lập; nút nhận được ngón thứ ba lúc hai joystick đang giữ
## (Godot chỉ giả lập chuột cho ngón đầu nên Button thường không làm được); nút đủ to, không chồng nhau, nằm trong tầm ngón cái;
## nút đổi theo ngữ cảnh (đi bộ/lái xe, Dùng chỉ khi có gì để dùng); thuận tay trái lật bố cục; thanh trượt cỡ nút phóng to nút.
func _check_touch_controls(city: Node) -> void:
	root.size = PHONE
	var tc: Node = load(TOUCH_CONTROLS).new()
	city.add_child(tc)
	await frames(3)
	var screen: Transform2D = root.get_final_transform()
	var view: Vector2 = root.get_visible_rect().size
	var move: Node = tc.move_stick
	var aim: Node = tc.aim_stick
	var left := view * Vector2(0.2, 0.7)
	var right := view * Vector2(0.6, 0.45)
	_touch(screen, 0, left, true)
	_touch(screen, 1, right, true)
	await frames(1)
	expect((move.global_position + move._center).distance_to(left) < 2.0, "joystick trái không đặt dưới ngón tay")
	_drag(screen, 0, left + Vector2(100, 0))
	_drag(screen, 1, right + Vector2(0, -100))
	await frames(1)
	expect(Input.get_action_strength(&"move_right") > 0.5, "kéo joystick trái sang phải mà không đi")
	expect(Input.get_action_strength(&"aim_up") > 0.5, "ngón thứ hai kéo lên mà không ngắm")
	expect(not Input.is_action_pressed(&"fire"), "kéo ngắm mà tự bắn: bắn phải là nút riêng")
	var fire: Node = tc.buttons.FIRE
	_touch(screen, 2, fire.get_global_rect().get_center(), true)
	await frames(2)
	expect(Input.is_action_pressed(&"fire"), "ngón thứ ba bấm nút BẮN lúc hai joystick đang giữ mà không bắn")
	_touch(screen, 2, fire.get_global_rect().get_center(), false)
	await frames(2)
	expect(not Input.is_action_pressed(&"fire"), "nhả nút BẮN mà vẫn bắn")
	_touch(screen, 0, left + Vector2(100, 0), false)
	_touch(screen, 1, right + Vector2(0, -100), false)
	await frames(1)
	expect(not Input.is_action_pressed(&"move_right") and not Input.is_action_pressed(&"aim_up"), "nhả tay mà action vẫn nhấn")
	# Đang giữ joystick thì game tạm dừng (hộp thoại, bản đồ, xoay dọc) và ngón tay nhấc ra lúc đó: không được kẹt.
	_touch(screen, 0, left, true)
	_drag(screen, 0, left + Vector2(100, 0))
	await frames(1)
	paused = true
	await frames(1)
	_touch(screen, 0, left + Vector2(100, 0), false)
	await frames(1)
	paused = false
	await frames(1)
	expect(not Input.is_action_pressed(&"move_right"), "nhấc ngón lúc tạm dừng thì joystick kẹt, nhân vật tự đi")
	_touch(screen, 0, left, true)
	_drag(screen, 0, left + Vector2(100, 0))
	await frames(1)
	expect(Input.get_action_strength(&"move_right") > 0.5, "sau khi tạm dừng, chạm lại joystick không còn tác dụng")
	_touch(screen, 0, left + Vector2(100, 0), false)
	await frames(1)
	# Giữ nút BẮN lúc game tạm dừng rồi nhấc ngón: nút phải nhả.
	_touch(screen, 3, fire.get_global_rect().get_center(), true)
	await frames(1)
	paused = true
	await frames(1)
	paused = false
	await frames(1)
	expect(not Input.is_action_pressed(&"fire"), "nút BẮN kẹt sau khi tạm dừng")
	_touch(screen, 3, fire.get_global_rect().get_center(), false)
	await frames(1)
	# Nút phụ không mở joystick ngắm.
	var reload: Node = tc.buttons.TOUCH_RELOAD
	_touch(screen, 2, reload.get_global_rect().get_center(), true)
	await frames(2)
	expect(aim._touch == -1 and Input.is_action_pressed(&"reload"), "chạm nút Nạp đạn mà mở joystick ngắm hoặc không nạp")
	_touch(screen, 2, reload.get_global_rect().get_center(), false)
	await frames(2)
	await _check_button_layout(tc, city, screen, view)
	await _check_left_hand(tc, screen)
	var before: float = tc.buttons.TOUCH_RELOAD.size.x
	game.settings.touch_scale = load("res://scripts/core/tuning.gd").TOUCH_SCALE_RANGE.x  # mức nhỏ nhất của thanh trượt
	get_nodes_in_group("touch_controls")[0].rebuild()
	await frames(3)
	var smallest: Vector2 = tc.buttons.TOUCH_RELOAD.size * minf(screen.get_scale().x, screen.get_scale().y)
	expect(smallest.x >= MIN_TAP, "cỡ nút nhỏ nhất chỉ %.0f px trên màn thật" % smallest.x)
	game.settings.touch_scale = 1.4
	get_nodes_in_group("touch_controls")[0].rebuild()
	await frames(3)
	expect(tc.buttons.TOUCH_RELOAD.size.x > before * 1.3, "cỡ nút 140%% mà nút không to lên")
	game.settings.touch_scale = 1.0
	tc.queue_free()
	root.size = Vector2i(1280, 720)
	await frames(2)


## Mọi nút hiện ra (đi bộ có Dùng, lái xe) đủ to trên màn thật, không chồng nhau, nút phụ nằm trong tầm ngón cái quanh nút BẮN;
## Dùng chỉ hiện khi có gì để dùng; đi bộ không có nút lái xe và ngược lại; tạm dừng xa các nút khác.
func _check_button_layout(tc: Node, city: Node, screen: Transform2D, view: Vector2) -> void:
	var scale: float = minf(screen.get_scale().x, screen.get_scale().y)
	city.interactions.prompt = ""
	tc._in_car = false
	tc._show_for_mode()
	expect(not tc.buttons.TOUCH_INTERACT.visible, "đi bộ mà không có gì để dùng nhưng nút Dùng vẫn hiện")
	city.interactions.prompt = "HINT_EXIT"
	tc._show_for_mode()
	expect(tc.buttons.TOUCH_INTERACT.visible, "có gì để dùng mà nút Dùng không hiện")
	expect(not tc.buttons.TOUCH_HANDBRAKE.visible and not tc.buttons.TOUCH_HORN.visible, "đi bộ mà hiện nút phanh tay/còi")
	_expect_spread(tc, scale, view, "đi bộ")
	tc._in_car = true
	tc._show_for_mode()
	expect(tc.buttons.TOUCH_HANDBRAKE.visible and tc.buttons.TOUCH_NITRO.visible and tc.buttons.TOUCH_EXIT.visible and tc.buttons.TOUCH_HORN.visible,
		"đang lái mà thiếu nút phanh tay/nitro/xuống xe/còi")
	expect(not tc.buttons.TOUCH_RELOAD.visible and not tc.buttons.TOUCH_SWAP.visible and not tc.buttons.TOUCH_INTERACT.visible, "đang lái mà còn nút đi bộ")
	_expect_spread(tc, scale, view, "lái xe")
	tc._in_car = false
	city.interactions.prompt = ""
	tc._show_for_mode()


func _expect_spread(tc: Node, scale: float, view: Vector2, mode: String) -> void:
	var shown: Array = tc.buttons.values().filter(func(b: Node) -> bool: return b.visible)
	var fire_at: Vector2 = tc.buttons.FIRE.get_global_rect().get_center()
	for b in shown:
		var tap: Vector2 = b.size * scale
		expect(minf(tap.x, tap.y) >= MIN_TAP, "%s: nút %s chỉ %s px trên màn thật" % [mode, b.caption, tap])
		expect(Rect2(Vector2.ZERO, view).encloses(b.get_global_rect()), "%s: nút %s tràn ra ngoài màn hình" % [mode, b.caption])
		if b != tc.buttons.PAUSE and b != tc.buttons.FIRE:
			expect(b.get_global_rect().get_center().distance_to(fire_at) <= REACH, "%s: nút %s ngoài tầm ngón cái quanh nút BẮN" % [mode, b.caption])
	for i in shown.size():
		for j in range(i + 1, shown.size()):
			var a: Rect2 = shown[i].get_global_rect()
			var c: Rect2 = shown[j].get_global_rect()
			var touching: bool = a.get_center().distance_to(c.get_center()) < (a.size.x + c.size.x) * 0.5
			expect(not touching, "%s: nút %s và %s chồng nhau" % [mode, shown[i].caption, shown[j].caption])
	var pause_at: Vector2 = tc.buttons.PAUSE.get_global_rect().get_center()
	for b in shown:
		if b != tc.buttons.PAUSE:
			expect(b.get_global_rect().get_center().distance_to(pause_at) >= PAUSE_CLEAR, "%s: nút %s quá gần nút Tạm dừng" % [mode, b.caption])


## Thuận tay trái: nút BẮN sang góc dưới trái, joystick di chuyển sang nửa phải.
func _check_left_hand(tc: Node, screen: Transform2D) -> void:
	game.settings.touch_left = true
	get_nodes_in_group("touch_controls")[0].rebuild()
	await frames(3)
	var view: Vector2 = root.get_visible_rect().size
	expect(tc.buttons.FIRE.get_global_rect().get_center().x < view.x * 0.5, "thuận tay trái mà nút BẮN vẫn bên phải")
	expect(tc.move_stick.anchor_left >= 0.5 and tc.aim_stick.anchor_left < 0.5, "thuận tay trái mà joystick di chuyển vẫn bên trái")
	_touch(screen, 4, tc.buttons.FIRE.get_global_rect().get_center(), true)
	await frames(2)
	expect(Input.is_action_pressed(&"fire"), "thuận tay trái: bấm nút BẮN không bắn")
	_touch(screen, 4, tc.buttons.FIRE.get_global_rect().get_center(), false)
	await frames(2)
	game.settings.touch_left = false
	get_nodes_in_group("touch_controls")[0].rebuild()
	await frames(3)


## Chạm/kéo như ngón tay thật: toạ độ cửa sổ (Input.parse_input_event đi qua phép co giãn màn hình).
func _touch(screen: Transform2D, index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = screen * pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(screen: Transform2D, index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = screen * pos
	Input.parse_input_event(e)


## Cầm dọc thì dừng game và hiện lớp phủ xoay ngang; ngang lại thì trả đúng trạng thái tạm dừng cũ; tắt thì không làm gì.
func _check_rotate_guard() -> void:
	var guard: Node = root.get_node_or_null("RotateGuard")
	expect(guard != null, "không có autoload RotateGuard")
	if guard == null:
		return
	guard.enabled = true
	paused = false
	await _resize(PORTRAIT)
	expect(paused and guard.visible, "cầm dọc mà game không dừng hoặc không hiện lớp phủ")
	await _resize(PHONE)
	expect(not paused and not guard.visible, "xoay ngang lại mà game vẫn dừng hoặc lớp phủ còn")
	paused = true
	await _resize(PORTRAIT)
	await _resize(PHONE)
	expect(paused, "đang tạm dừng sẵn, xoay dọc rồi ngang thì game tự chạy lại")
	paused = false
	guard.enabled = false
	await _resize(PORTRAIT)
	expect(not paused and not guard.visible, "máy không cảm ứng mà vẫn chặn màn dọc")
	await _resize(Vector2i(1280, 720))


func _resize(size: Vector2i) -> void:
	root.size = size
	await frames(3)


## Trên máy cảm ứng: gợi ý ghi tên nút cảm ứng thay vì phím, hướng dẫn dạy joystick, chạm bản đồ nhỏ mở bản đồ.
func _check_touch_hints() -> void:
	var touch: GDScript = load(TOUCH_CONTROLS)
	var input_setup: GDScript = load(INPUT_SETUP)
	expect(input_setup.key_label(&"interact") == "E", "máy tính: gợi ý Dùng không ghi phím E")
	touch.forced = true
	expect(input_setup.key_label(&"interact") == tr("TOUCH_INTERACT"), "cảm ứng: gợi ý vẫn ghi phím E thay vì nút Dùng")
	var city := await open_city()
	var tutorial: Node = city.get_node_or_null("Tutorial")
	expect(tutorial != null and tutorial._steps[0][0] == "TUT_MOVE_TOUCH", "hướng dẫn trên điện thoại vẫn dạy W A S D")
	var mini: Control = city.hud.find_child("MinimapPanel", true, false)
	expect(mini != null, "không tìm thấy bản đồ nhỏ")
	if mini != null:
		var screen := root.get_final_transform()
		var at := mini.get_global_rect().get_center()
		_touch(screen, 0, at, true)
		await frames(2)
		_touch(screen, 0, at, false)
		await frames(2)
		var opened: Node = city.overlays.current
		expect(opened != null and opened.get_script().resource_path.ends_with("map_screen.gd"), "chạm bản đồ nhỏ không mở bản đồ")
		var move: Node = get_nodes_in_group("touch_controls")[0].move_stick
		expect(move._touch == -1, "chạm bản đồ nhỏ mà joystick trái cũng bắt ngón tay")
		_touch(screen, 1, root.get_visible_rect().get_center(), true)
		await frames(2)
		_touch(screen, 1, root.get_visible_rect().get_center(), false)
		await frames(2)
		expect(city.overlays.current == null, "trên điện thoại chạm vào bản đồ không đóng được bản đồ")
	await close_overlays(city)
	TranslationServer.pseudolocalization_enabled = true
	var settings: Node = load("res://scripts/ui/settings_panel.gd").new()
	city.add_child(settings)
	await frames(3)
	expect(settings.panel.size.y <= root.get_visible_rect().size.y, "Cài đặt (pseudo, cảm ứng) cao %.0f px, tràn khung" % settings.panel.size.y)
	settings.close()
	TranslationServer.pseudolocalization_enabled = false
	touch.forced = false
	await frames(2)
