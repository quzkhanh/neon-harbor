extends "res://tests/harness.gd"
## Hoàn thành lần lượt 3 nhiệm vụ qua API kiểm thử (dịch chuyển, hạ mục tiêu).
## Assert tiền tăng đúng, súng mở bán đúng, lưu rồi nạp lại save.json giữ nguyên state,
## chết: về bệnh viện gần nhất mất 10% tiền; làm lại nhiệm vụ; hồi sinh tại chỗ mất 20% và giữ sao.
## NV2 được Rosa trang bị; thất bại không do chết thì hỏi làm lại; máu tự hồi tới mức trần.

const UNLOCKS := {1: ["smg"], 2: ["rifle", "flamethrower"], 3: ["sniper", "bazooka"]}
const MAX_WAIT := 300
const REVIVE_HOSPITAL := 0  # khớp DeathScreen.Revive (test không được tham chiếu class_name của game)
const REVIVE_HERE := 1
const REVIVE_RETRY := 3


func _run() -> void:
	var city := await open_city()
	for n in [1, 2, 3]:
		city = await _play_mission(city, n)
	expect(game.missions_done == [1, 2, 3], "missions_done sai: %s" % [game.missions_done])
	await _wait(func() -> bool: return current_scene != null and current_scene.scene_file_path == game.ENDING_SCENE, "xong NV3 không sang màn kết")
	_check_save_roundtrip()
	city = await open_city()
	await _check_death(city)
	await _check_fail_retry(city)
	await _check_regen(city)
	finish("MISSIONS")


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
	expect(city.player.global_position.distance_to(city.missions.giver_pos(1)) < 10.0, "làm lại: không về điểm nhận NV1")


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


func _check_save_roundtrip() -> void:
	game.owned["smg"] = {"mag": 7, "reserve": 33}
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


func _wait(cond: Callable, message: String) -> void:
	for i in MAX_WAIT:
		if cond.call():
			return
		await frames(1)
	expect(false, message)
