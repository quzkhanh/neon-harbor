class_name Lanes
extends Object
## Quy tắc làn đường có hướng (khớp tools/checks/validate_map.py):
## ô làn chỉ đi theo hướng của nó; "=" giữ nguyên hướng; trong khối "+" được rẽ (không quay đầu)
## sang ô "+" khác hoặc ra một làn cùng chiều với hướng rẽ.


## Ô tiếp theo khi đang ở `cell` với hướng `heading` ngoài giao lộ.
static func step(map: MapData, cell: Vector2i, heading: Vector2i) -> Vector2i:
	var d := map.lane_dir(cell)
	return cell + (d if d != Vector2i.ZERO else heading)


## Có được đi vào ô `cell` theo hướng `d` không (tính cả chuỗi "=" phía sau).
static func can_enter(map: MapData, cell: Vector2i, d: Vector2i) -> bool:
	var c := cell
	while map.at(c) == "=":
		c += d
	return map.at(c) == "+" or map.lane_dir(c) == d


## Lộ trình qua khối giao lộ bắt đầu ở `entry`: danh sách ô, kết thúc ở ô lối ra. Chọn ngẫu nhiên, ưu tiên đi thẳng.
static func plan_intersection(map: MapData, entry: Vector2i, heading: Vector2i) -> Array[Vector2i]:
	var came := {entry: entry}
	var queue: Array[Vector2i] = [entry]
	var exits: Array = []
	while queue.size() > 0:
		var c: Vector2i = queue.pop_front()
		for d in MapData.DIRS:
			var n: Vector2i = c + d
			if map.at(n) == "+":
				if not came.has(n):
					came[n] = c
					queue.append(n)
			elif map.is_road(n) and d != -heading and can_enter(map, n, d):
				exits.append([c, n, d])
	if exits.is_empty():
		return [entry]
	var weighted: Array = []
	for e in exits:
		weighted.append(e)
		if e[2] == heading:
			weighted.append(e)
	var pick: Array = weighted[randi() % weighted.size()]
	var route: Array[Vector2i] = [pick[1]]
	var c: Vector2i = pick[0]
	while c != entry:
		route.push_front(c)
		c = came[c]
	route.push_front(entry)
	return route
