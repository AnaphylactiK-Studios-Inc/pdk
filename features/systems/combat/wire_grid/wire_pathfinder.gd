extends RefCounted
class_name WirePathfinder

var astar := AStarGrid2D.new()

func setup(size: int):
	astar.region = Rect2i(0, 0, size, size)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()

func generate_path(
	size: int,
	waypoint_count: int,
	start_pos: Vector2i,
	end_pos: Vector2i
) -> Array[Vector2i]:
	if size <= 0:
		return []

	setup(size)

	start_pos = clamp_endpoint(start_pos, size)
	end_pos = clamp_endpoint(end_pos, size)

	var start_cell := get_adjacent_cell(start_pos, size)
	var end_cell := get_adjacent_cell(end_pos, size)

	var path: Array[Vector2i] = [start_cell]
	var visited := {start_cell: true}

	var found := generate_path_recursive(
		path,
		visited,
		end_cell,
		max(waypoint_count, 0)
	)

	if not found:
		path = generate_fallback_path(start_cell, end_cell)

	return path

func clamp_endpoint(pos: Vector2i, size: int) -> Vector2i:
	var x: int = clampi(pos.x, -1, size)
	var y: int = clampi(pos.y, -1, size)

	if x == -1 or x == size:
		y = clampi(y, 0, size - 1)
	else:
		x = clampi(x, 0, size - 1)

	return Vector2i(x, y)

func get_adjacent_cell(endpoint: Vector2i, size: int) -> Vector2i:
	if endpoint.x == -1:
		return Vector2i(0, endpoint.y)

	if endpoint.x == size:
		return Vector2i(size - 1, endpoint.y)

	if endpoint.y == -1:
		return Vector2i(endpoint.x, 0)

	if endpoint.y == size:
		return Vector2i(endpoint.x, size - 1)

	return endpoint

func generate_path_recursive(
	path: Array[Vector2i],
	visited: Dictionary,
	end_pos: Vector2i,
	detours_remaining: int
) -> bool:
	var current: Vector2i = path.back()

	if current == end_pos:
		return true

	var neighbors := get_valid_neighbors(current, visited)

	if neighbors.is_empty():
		return false

	var scored_neighbors: Array = []

	for neighbor in neighbors:
		var score := score_cell(
			neighbor,
			current,
			end_pos,
			detours_remaining
		)

		scored_neighbors.append({
			"cell": neighbor,
			"score": score
		})

	scored_neighbors.sort_custom(func(a, b):
		return a.score > b.score
	)

	for option in scored_neighbors:
		var next: Vector2i = option.cell
		var next_detours_remaining := detours_remaining

		if is_detour(current, next, end_pos):
			if next_detours_remaining > 0:
				next_detours_remaining -= 1

		visited[next] = true
		path.append(next)

		if generate_path_recursive(
			path,
			visited,
			end_pos,
			next_detours_remaining
		):
			return true

		path.pop_back()
		visited.erase(next)

	return false

func get_valid_neighbors(
	current: Vector2i,
	visited: Dictionary
) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = [
		current + Vector2i(1, 0),
		current + Vector2i(-1, 0),
		current + Vector2i(0, 1),
		current + Vector2i(0, -1)
	]

	var valid: Array[Vector2i] = []

	for neighbor in neighbors:
		if not astar.is_in_boundsv(neighbor):
			continue

		if visited.has(neighbor):
			continue

		valid.append(neighbor)

	return valid

func score_cell(
	cell: Vector2i,
	current: Vector2i,
	end_pos: Vector2i,
	detours_remaining: int
) -> float:
	var score := 0.0

	if is_detour(current, cell, end_pos):
		if detours_remaining > 0:
			score += 20.0
		else:
			score += 2.0
	else:
		score += 10.0

	var onward := get_distance_to_edge(cell)

	score += float(onward) * 0.5
	score += randf_range(0.0, 3.0)

	return score

func is_detour(
	current: Vector2i,
	next: Vector2i,
	end_pos: Vector2i
) -> bool:
	var current_distance := manhattan_distance(current, end_pos)
	var next_distance := manhattan_distance(next, end_pos)

	return next_distance > current_distance

func manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func get_distance_to_edge(cell: Vector2i) -> int:
	var left := cell.x
	var right := astar.region.size.x - 1 - cell.x
	var top := cell.y
	var bottom := astar.region.size.y - 1 - cell.y

	return mini(mini(left, right), mini(top, bottom))

func generate_fallback_path(
	start_pos: Vector2i,
	end_pos: Vector2i
) -> Array[Vector2i]:
	var path: Array[Vector2i] = [start_pos]
	var current := start_pos

	while current.x != end_pos.x:
		current.x += signi(end_pos.x - current.x)
		path.append(current)

	while current.y != end_pos.y:
		current.y += signi(end_pos.y - current.y)
		path.append(current)

	return path
