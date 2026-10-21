extends RefCounted
class_name WireGridGenerator

var grid: WireGrid
var pathfinder := WirePathfinder.new()

var connection_tiles: Dictionary = {}
var tile_usage: Dictionary = {}

func _init(target_grid: WireGrid):
	grid = target_grid

func generate() -> Array[Vector2i]:
	if grid.source == null or grid.destination == null:
		push_error("WireGrid requires a source and destination endpoint.")
		return []

	if not build_connection_lookup():
		return []

	return generate_wire()

func build_connection_lookup() -> bool:
	connection_tiles.clear()
	tile_usage.clear()

	for tile_id: Vector2i in grid.off_tile_connections:
		var rotated_connections: int = grid.off_tile_connections[tile_id]
		var seen_connections := {}

		tile_usage[tile_id] = 0

		for rotation in range(4):
			if not seen_connections.has(rotated_connections):
				seen_connections[rotated_connections] = true
				add_connection_options(tile_id, rotation, rotated_connections)

			rotated_connections = WireGrid.rotate_connections(rotated_connections)

	if connection_tiles.is_empty():
		push_error("No valid wire tiles found.")
		return false

	return true

func add_connection_options(tile_id: Vector2i, rotation: int, rotated_connections: int):
	for required_connections in range(1, 16):
		if (rotated_connections & required_connections) != required_connections:
			continue

		if not connection_tiles.has(required_connections):
			connection_tiles[required_connections] = []

		connection_tiles[required_connections].append({
			"tile_id": tile_id,
			"rotation": rotation,
			"rotated_connections": rotated_connections
		})

func generate_wire() -> Array[Vector2i]:
	grid.clear()

	var source_id := grid.atlas_source_id
	var start_pos: Vector2i = grid.source.coordinate
	var end_pos: Vector2i = grid.destination.coordinate

	var path: Array[Vector2i] = pathfinder.generate_path(
		grid.size,
		grid.waypoint_count,
		grid.get_adjacent_cell(start_pos),
		grid.get_adjacent_cell(end_pos)
	)

	if path.is_empty():
		push_warning("WirePathfinder did not generate a path.")
		return path

	place_path(path, source_id, start_pos, end_pos)
	fill_remaining_cells(path, source_id)
	scramble_path(path)

	return path

func place_path(
	path: Array[Vector2i],
	source_id: int,
	start_pos: Vector2i,
	end_pos: Vector2i
):
	for i in range(path.size()):
		var cell := path[i]
		var required_connections := 0

		if i == 0:
			required_connections |= WireGrid.get_direction(cell, start_pos)
		else:
			required_connections |= WireGrid.get_direction(cell, path[i - 1])

		if i == path.size() - 1:
			required_connections |= WireGrid.get_direction(cell, end_pos)
		else:
			required_connections |= WireGrid.get_direction(cell, path[i + 1])

		if not connection_tiles.has(required_connections):
			push_warning("No valid tile for connections: %s" % required_connections)
			continue

		var options: Array = connection_tiles[required_connections]
		var choice: Dictionary = choose_tile(options)

		if choice.is_empty():
			push_warning("Could not choose a tile for connections: %s" % required_connections)
			continue

		var tile_id: Vector2i = choice.tile_id
		var rotation: int = choice.rotation

		tile_usage[tile_id] = tile_usage.get(tile_id, 0) + 1

		grid.set_cell(
			cell,
			source_id,
			tile_id,
			WireGrid.get_rotation_transform(rotation)
		)

func fill_remaining_cells(
	path: Array[Vector2i],
	source_id: int
):
	var path_cells := {}

	for cell in path:
		path_cells[cell] = true

	var valid_tiles: Array = grid.off_tile_connections.keys()

	if valid_tiles.is_empty():
		push_warning("No valid tiles found.")
		return

	for y in range(grid.size):
		for x in range(grid.size):
			var cell := Vector2i(x, y)

			if path_cells.has(cell):
				continue

			var tile_id: Vector2i = valid_tiles.pick_random()
			var rotation := randi_range(0, 3)

			grid.set_cell(
				cell,
				source_id,
				tile_id,
				WireGrid.get_rotation_transform(rotation)
			)

func choose_tile(options: Array) -> Dictionary:
	var best_score := INF
	var best_option: Dictionary = {}

	for option in options:
		var tile_id: Vector2i = option.tile_id
		var usage: int = tile_usage.get(tile_id, 0)
		var connections: int = count_connections(option.rotated_connections)
		var score := usage * 3 + connections * 10 + randf_range(0.0, 2.0)

		if score < best_score:
			best_score = score
			best_option = option

	return best_option

func count_connections(connections: int) -> int:
	var count := 0

	for direction in WireGrid.DIRECTIONS:
		if connections & direction:
			count += 1

	return count

func scramble_path(path: Array[Vector2i]):
	for cell in path:
		var tile_id := grid.get_cell_atlas_coords(cell)
		var source_id := grid.get_cell_source_id(cell)

		var rotation := randi_range(0, 3)

		grid.set_cell(
			cell,
			source_id,
			tile_id,
			WireGrid.get_rotation_transform(rotation)
		)
