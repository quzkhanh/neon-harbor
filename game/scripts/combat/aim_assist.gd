class_name AimAssist
extends Object
## Hỗ trợ ngắm khi dùng joystick ảo/analog: hướng vào tên băng đảng, hoặc cảnh sát khi đang bị truy nã, lệch ít nhất so với
## hướng ngắm, trong nón ±Tuning.AIM_ASSIST_DEG, trong tầm súng và không bị tường chắn. Không bao giờ nhắm người đi đường.


static func pick(shooter: Node2D, angle: float, max_range: float) -> float:
	var tree := shooter.get_tree()
	var targets := tree.get_nodes_in_group("gang")
	if Game.stars > 0:
		targets += tree.get_nodes_in_group("cops")
	var space := shooter.get_world_2d().direct_space_state
	var best := angle
	var best_off := deg_to_rad(Tuning.AIM_ASSIST_DEG)
	for t in targets:
		var to: Vector2 = t.global_position - shooter.global_position
		var off := absf(angle_difference(angle, to.angle()))
		if not t.alive or off >= best_off or to.length() > max_range:
			continue
		var q := PhysicsRayQueryParameters2D.create(shooter.global_position, t.global_position, Tuning.LAYER_WORLD)
		if space.intersect_ray(q).is_empty():
			best = to.angle()
			best_off = off
	return best
