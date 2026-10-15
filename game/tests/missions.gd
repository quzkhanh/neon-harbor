extends "res://tests/harness.gd"
## Hoàn thành lần lượt 9 nhiệm vụ qua API kiểm thử (dịch chuyển, hạ mục tiêu).
## Assert tiền tăng đúng, súng mở bán đúng, lưu rồi nạp lại save.json giữ nguyên state,
## chết: về bệnh viện gần nhất mất 10% tiền; làm lại nhiệm vụ; hồi sinh tại chỗ mất 20% và giữ sao.
## NV2 được Rosa trang bị; thất bại không do chết thì hỏi làm lại; máu tự hồi tới mức trần.
## Mọi súng đạn vô hạn: bắn hết băng rồi nạp lại đầy, lặp nhiều lần.

const UNLOCKS := {1: ["smg"], 2: ["rifle", "flamethrower"], 3: ["sniper", "bazooka"], 4: [], 5: [], 6: [], 7: [], 8: [], 9: []}
const MISSIONS := [1, 2, 3, 4, 5, 6, 7, 8, 9]
const MAX_WAIT := 300
const REVIVE_HOSPITAL := 0  # khớp DeathScreen.Revive (test không được tham chiếu class_name của game)
const REVIVE_HERE := 1
const REVIVE_RETRY := 2
const REVIVE_SAFEHOUSE := 3


func _run() -> void:
	watchdog_sec = 240.0
	var city := await open_city()
	for n in MISSIONS:
		city = await _play_mission(city, n)
		if n == 3:
			expect(current_scene == city and current_scene.scene_file_path == game.CITY_SCENE, "xong NV3 mà rời thành phố (cốt truyện có 9 nhiệm vụ)")
	expect(game.missions_done == MISSIONS, "missions_done sai: %s" % [game.missions_done])
	await _wait(func() -> bool: return current_scene != null and current_scene.scene_file_path == game.ENDING_SCENE, "xong NV9 không sang màn kết")
	_check_save_roundtrip()
	_check_infinite_ammo()
	city = await open_city()
	await _check_death(city)
	await _check_fail_retry(city)
	await _check_regen(city)
	await _check_stale_signals(city)
	finish("MISSIONS")


## Nhiệm vụ đã kết thúc (vd. chết vì bom NV6) mà sau đó mới phát `completed` thì không được tính xong / trả tiền;
## hoàn thành lại một nhiệm vụ đã xong không trả tiền lần nữa.
func _check_stale_signals(city: Node) -> void:
	await close_overlays(city)
	game.missions_done = []
	city.missions.start(1, false)
	await frames(3)
	var m: Node = city.missions.current
	city.missions.on_player_died()
	var money: int = game.money
	m.completed.emit()
	await frames(5)
	expect(not 1 in game.missions_done and game.money == money, "nhiệm vụ đã thất bại vẫn được tính hoàn thành")
	game.missions_done = [1]
	game.complete_mission(1)
	expect(game.missions_done == [1] and game.money == money, "hoàn thành lại NV đã xong mà vẫn trả tiền / ghi trùng")
	city.missions.retry_mission = 0


## Thất bại không do chết: hỏi làm lại; đồng ý thì về điểm nhận và nhiệm vụ chạy lại ngay.
func _check_fail_retry(city: Node) -> void:
	await close_overlays(city)
	game.missions_done = []
	city.missions.start(1, false)
	await frames(3)
	city.missions.current.failed.emit("M1_FAIL_LATE")
	await _wait(func() -> bool: return city.overlays.current != null, "NV1 thất bại: không hỏi làm lại")
	city.overlays.current.close(true)
	await frames(5)
	expect(city.missions.current != null and city.missions.current_n == 1, "NV1 thất bại -> làm lại: nhiệm vụ không chạy lại")
	var off: float = city.player.global_position.distance_to(city.missions.giver_pos(1))
	expect(off < 10.0, "làm lại: không về điểm nhận NV1 (cách %.0f px, trên xe: %s, còn sống: %s)" % [off, city.player.vehicle != null, city.player.alive])


## Không trúng đòn một lúc thì máu tự hồi, nhưng chỉ tới REGEN_CAP.
func _check_regen(city: Node) -> void:
	game.clear_wanted()
	city.police.clear_all()
	await physics(200)  # hết thời gian bất tử của lần hồi sinh tại chỗ trước đó
	game.armor = 0.0
	city.player.take_hit(70.0, Vector2.RIGHT, null)
	var low: float = game.health
	await physics(60 * 12)
	expect(game.health > low and game.health <= 60.0 + 0.01, "hồi máu: %.1f -> %.1f (mong tăng, tối đa 60)" % [low, game.health])


func _play_mission(city: Node, n: int) -> Node:
	var p: Node = city.player
	expect(game.next_mission() == n, "nhiệm vụ kế tiếp phải là %d" % n)
	for id in UNLOCKS[n]:
		expect(not game.is_unlocked(id), "NV%d: %s đã mở bán quá sớm" % [n, id])
	p.global_position = city.missions.giver_pos(n)
	await _wait(func() -> bool: return city.overlays.current != null, "NV%d: không mở hội thoại" % n)
	await close_overlays(city)
	await _wait(func() -> bool: return city.missions.current != null, "NV%d: không bắt đầu" % n)
	var mission: Node = city.missions.current
	match n:
		1:
			p.enter_vehicle(mission.bike)
			await frames(5)
			mission.bike.global_position = mission.cell_pos("d")
		2:
			expect(game.current == "smg" and game.armor >= 100.0, "NV2: Rosa chưa đưa tiểu liên + áo giáp (%s, giáp %d)" % [game.current, game.armor])
			for g in get_nodes_in_group("gang"):
				g.take_hit(999.0, Vector2.RIGHT, p)
			await frames(5)
			expect(game.objective == "M2_OBJ_CASE", "NV2: chưa hiện mục tiêu nhặt vali (%s)" % game.objective)
			p.global_position = mission.cell_pos("r")
			await _wait(func() -> bool: return game.objective == "M2_OBJ_RETURN", "NV2: không nhặt được vali")
			p.global_position = mission.cell_pos("2")
		3:
			p.enter_vehicle(mission.car)
			await frames(5)
			expect(game.stars == 2, "NV3: cướp xe phải lên 2 sao (đang %d)" % game.stars)
			game.clear_wanted()
			await frames(5)
			expect(game.objective == "M3_OBJ_GARAGE", "NV3: cắt đuôi xong chưa hiện mục tiêu gara (%s)" % game.objective)
			mission.car.global_position = mission.cell_pos("G")
		4:
			p.enter_vehicle(mission._car)
			await frames(5)
			var courier: Node = mission.courier
			expect(not courier.autopilot.waiting, "NV4: lên xe rồi mà xe đưa tin chưa chạy")
			await physics(60)
			expect(game.objective in ["M4_OBJ_TAIL", "M4_OBJ_CLOSE", "M4_OBJ_FAR"], "NV4: mục tiêu bám đuôi sai (%s)" % game.objective)
			courier.global_position = courier.autopilot.target
			mission._car.global_position = courier.autopilot.target + Vector2(400, 0)
		5:
			expect(game.current == "rifle", "NV5: Rosa chưa đưa súng trường")
			p.global_position = mission.cell_pos("y")
			for wave in 3:
				await _wait(func() -> bool: return _alive_gang().size() > 0, "NV5: đợt %d không tới" % (wave + 1))
				for g in _alive_gang():
					g.take_hit(999.0, Vector2.RIGHT, p)
				await frames(3)
		6:
			var car: Node = mission.car
			p.enter_vehicle(car)
			for i in 10:
				car.velocity = Vector2.from_angle(car.rotation) * 320.0
				await physics_frame
			expect(mission._armed, "NV6: chạy nhanh mà bom chưa kích hoạt")
			car.global_position = mission.cell_pos("F") + Vector2(300, 0)
			car.velocity = Vector2(-300, 0)
			await physics(2)
			p.exit_vehicle()
			p.global_position = mission.cell_pos("F") + Vector2(900, 0)
		7:
			var v: Node = city.spawn_vehicle("car", Vector2i(mission.cell_pos("i") / 64.0), 0.0)
			p.enter_vehicle(v)
			v.global_position = mission.cell_pos("i")
			v.velocity = Vector2.ZERO
			await _wait(func() -> bool: return mission._aboard, "NV7: dừng cạnh Vince mà anh ta không lên xe")
			v.global_position = mission.cell_pos("e")
			v.velocity = Vector2.ZERO
		8:
			game.clear_wanted()  # NV7 dịch chuyển xe đè người đi đường: sao còn sót không phải do NV8
			await frames(2)
			p.enter_vehicle(mission.truck)
			await frames(5)
			expect(game.stars == 0, "NV8: vừa lên xe tải, chưa chạy khỏi bãi đã bị truy nã")
			mission.truck.global_position += Vector2(0, -600)
			await frames(5)
			expect(game.stars == 3, "NV8: chạy xe tải khỏi bãi phải lên 3 sao (đang %d)" % game.stars)
			game.clear_wanted()
			await frames(5)
			mission.truck.global_position = mission.cell_pos("G")
		9:
			expect(is_instance_valid(mission.boss) and mission.boss.max_health > 300.0, "NV9: không có trùm Silas")
			mission.boss.knock_down(Vector2(400, 0), 9999.0, null)  # xe tự lái tông phải
			expect(mission.boss.alive and not mission._escaping, "NV9: xe tự lái tông chết trùm thay người chơi")
			for g in _alive_gang():
				g.take_hit(9999.0, Vector2.RIGHT, p)
			await frames(5)
			expect(game.stars == 4, "NV9: hạ trùm xong phải lên 4 sao (đang %d)" % game.stars)
			game.clear_wanted()
	var money_before: int = game.money
	await _wait(func() -> bool: return city.missions.current == null, "NV%d: không hoàn thành" % n)
	await _wait(func() -> bool: return city.overlays.current != null, "NV%d: không có hội thoại kết" % n)
	await close_overlays(city)
	var reward := int(game.mission(n).reward)
	expect(game.money == money_before + reward, "NV%d: tiền %d, mong đợi %d" % [n, game.money, money_before + reward])
	expect(n in game.missions_done, "NV%d chưa được ghi là xong" % n)
	for id in UNLOCKS[n]:
		expect(game.is_unlocked(id), "NV%d: %s chưa mở bán" % [n, id])
	await frames(30)
	return current_scene


func _alive_gang() -> Array:
	return get_nodes_in_group("gang").filter(func(g: Node) -> bool: return g.alive)


func _check_save_roundtrip() -> void:
	game.owned["smg"] = {"mag": 7}
	game.settings.lang = "vi"
	game.save_game()
	var snapshot := [game.money, game.owned.duplicate(true), game.missions_done.duplicate(), game.settings.duplicate()]
	game.reset_progress()
	game.settings.lang = "en"
	game.load_game()
	var after := [game.money, game.owned, game.missions_done, game.settings]
	expect(snapshot[0] == after[0], "lưu/nạp: tiền %s != %s" % [snapshot[0], after[0]])
	expect(snapshot[1] == after[1], "lưu/nạp: súng/đạn %s != %s" % [snapshot[1], after[1]])
	expect(snapshot[2] == after[2], "lưu/nạp: nhiệm vụ %s != %s" % [snapshot[2], after[2]])
	expect(snapshot[3] == after[3], "lưu/nạp: cài đặt %s != %s" % [snapshot[3], after[3]])
	game.set_setting("lang", "en")


func _check_infinite_ammo() -> void:
	for w in JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons.json")):
		if w.kind == "melee":  # tay không, gậy: không có băng đạn
			continue
		game.grant_weapon(w.id)
		for cycle in 3:
			while game.consume_ammo():
				pass
			expect(game.can_reload(), "%s: hết băng lần %d mà không nạp được" % [w.id, cycle + 1])
			game.finish_reload()
			expect(int(game.ammo().mag) == int(w.mag), "%s: nạp lại không đầy băng" % w.id)


func _check_death(city: Node) -> void:
	game.add_money(1000 - game.money)
	game.set_stars(2)
	var p: Node = city.player
	var died_at: Vector2 = p.global_position
	p.take_hit(999.0, Vector2.RIGHT, null)
	await _wait(func() -> bool: return city.overlays.current != null, "chết: không hiện màn chết")
	city.overlays.current.close(REVIVE_HOSPITAL)
	await frames(5)
	var hospital: Vector2 = city.nearest_hospital(died_at)
	expect(p.alive, "chết: không hồi sinh")
	expect(p.global_position.distance_to(hospital) < 10.0, "chết: không về bệnh viện (%s)" % p.global_position)
	expect(game.money == 900, "chết: tiền %d, mong đợi 900 (mất 10%%)" % game.money)
	expect(game.stars == 0, "chết: vẫn còn %d sao" % game.stars)

	# Chết giữa nhiệm vụ -> "Làm lại nhiệm vụ": về điểm nhận nhiệm vụ, nhiệm vụ chạy lại ngay (không hội thoại).
	game.missions_done = []
	city.missions.start(1, false)
	await frames(3)
	p.take_hit(999.0, Vector2.RIGHT, null)
	await _wait(func() -> bool: return city.overlays.current != null, "chết giữa NV1: không hiện màn chết")
	expect(city.missions.retry_mission == 1, "chết giữa NV1: màn chết không cho làm lại")
	var money_before_retry: int = game.money
	city.overlays.current.close(REVIVE_RETRY)
	await frames(5)
	expect(city.missions.current != null and city.missions.current_n == 1, "làm lại: NV1 không chạy lại")
	expect(p.global_position.distance_to(city.missions.giver_pos(1)) < 10.0, "làm lại: không về điểm nhận NV1")
	expect(game.money == money_before_retry, "làm lại sau khi chết phải miễn phí (tiền %d -> %d)" % [money_before_retry, game.money])

	# Hồi sinh tại chỗ: mất 20% tiền, giữ sao truy nã, không đổi vị trí.
	city.missions.current.failed.emit("FAIL_DIED")
	game.money = 1000
	game.set_stars(2)
	var here: Vector2 = p.global_position
	p.take_hit(999.0, Vector2.RIGHT, null)
	await _wait(func() -> bool: return city.overlays.current != null, "chết lần 3: không hiện màn chết")
	city.overlays.current.close(REVIVE_HERE)
	await frames(5)
	expect(p.alive and p.global_position.distance_to(here) < 10.0, "hồi sinh tại chỗ: bị dời đi")
	expect(game.money == 800 and game.stars == 2, "hồi sinh tại chỗ: tiền %d (mong 800), sao %d (mong 2)" % [game.money, game.stars])
	p.take_hit(999.0, Vector2.RIGHT, null)
	expect(p.alive, "hồi sinh tại chỗ: không có thời gian bất tử")
	await _check_safehouse_revive(city)
	# Đứng sát gốc cây (ô "đặc" nhưng vẫn đứng được) thì không bị dời; dưới nước thì được kéo lên bờ.
	var tree: Vector2i = city.data.find("T")
	var beside := (Vector2(tree) + Vector2(0.5, 0.5)) * 64.0 + Vector2(28, 0)
	expect(city.nearest_land(beside) == beside, "hồi sinh cạnh gốc cây mà bị dời đi")
	var sea := (Vector2(city.data.find("~")) + Vector2(0.5, 0.5)) * 64.0
	expect(city.data.at(Vector2i(city.nearest_land(sea) / 64.0)) != "~", "chết đuối hồi sinh tại chỗ mà vẫn ở dưới nước")


## Đã mua nhà an toàn: màn chết có thêm "Về nhà an toàn" (miễn phí, xoá truy nã); chưa mua thì nút ẩn.
func _check_safehouse_revive(city: Node) -> void:
	var p: Node = city.player
	await physics(200)  # hết thời gian bất tử của lần hồi sinh tại chỗ trước
	game.missions_done = range(1, 10)  # không để nhiệm vụ nào tự mở khi đứng cạnh điểm nhận
	await close_overlays(city)
	if city.missions.current:
		city.missions.current.failed.emit("FAIL_DIED")
	await close_overlays(city)
	p.global_position = city.nearest_hospital(p.global_position) + Vector2(0, 128)
	game.stats.erase("safehouses")
	await physics(200)
	p.take_hit(999.0, Vector2.RIGHT, null)
	await _wait(func() -> bool: return city.overlays.current is CanvasLayer and city.overlays.current.has_method("_fee_button"), "chết lần 4: không hiện màn chết")
	expect(not _home_button(city.overlays.current).visible, "chưa mua nhà mà màn chết có nút về nhà an toàn")
	city.overlays.current.close(REVIVE_HERE)
	await physics(200)
	game.mark("safehouses", "0")
	game.money = 1000
	game.set_stars(3)
	p.take_hit(999.0, Vector2.RIGHT, null)
	await _wait(func() -> bool: return city.overlays.current is CanvasLayer and city.overlays.current.has_method("_fee_button"), "chết lần 5: không hiện màn chết")
	expect(_home_button(city.overlays.current).visible, "đã mua nhà mà màn chết không có nút về nhà an toàn")
	city.overlays.current.close(REVIVE_SAFEHOUSE)
	await frames(5)
	var home: Vector2 = city.properties.safehouses[0]
	expect(p.alive and p.global_position.distance_to(home) < 10.0, "về nhà an toàn: không hồi sinh ở cửa nhà (%s)" % p.global_position)
	expect(game.money == 1000 and game.stars == 0, "về nhà an toàn: tiền %d (mong 1000), sao %d (mong 0)" % [game.money, game.stars])


func _home_button(screen: Node) -> Button:
	for b in screen.find_children("*", "Button", true, false):
		if b.text == "DEATH_SAFEHOUSE":
			return b
	return Button.new()


func _wait(cond: Callable, message: String) -> void:
	for i in MAX_WAIT:
		if cond.call():
			return
		await frames(1)
	expect(false, message)
