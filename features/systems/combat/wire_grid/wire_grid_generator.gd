extends RefCounted
class_name WireGridGenerator

var grid: WireGrid
var pathfinder := WirePathfinder.new()

var connection_tiles: Dictionary = {}
var tile_usage: Dictionary = {}

const TOP := 1
const RIGHT := 2
const BOTTOM := 4
const LEFT := 8

func _init(target_grid: WireGrid):
	grid = target_grid

func generate():
	if grid.source == null or grid.destination == null:
		push_error("WireGrid requires a source and destination endpoint.")
		return

	if not build_connection_lookup():
		return

	generate_wire()

func build_connection_lookup() -> bool:
	connection_tiles.clear()
	tile_usage.clear()

	var source_id := grid.tile_set.get_source_id(0)
	var atlas := grid.tile_set.get_source(source_id) as TileSetAtlasSource

	if atlas == null:
		push_error("No TileSetAtlasSource found.")
		return false

	for i in range(atlas.get_tiles_count()):
		var tile_id := atlas.get_tile_id(i)
		var tile_data := atlas.get_tile_data(tile_id, 0)

		if tile_data == null:
			continue

		var is_on: bool = tile_data.get_custom_data("IsOn")

		if is_on:
			continue

		var base_connections: int = tile_data.get_custom_data("Connections")
		var rotated_connections := base_connections

		tile_usage[tile_id] = 0

		for rotation in range(4):
			for required_connections in range(16):
				if (rotated_connections & required_connections) != required_connections:
					continue

				if not connection_tiles.has(required_connections):
					connection_tiles[required_connections] = []

				connection_tiles[required_connections].append({
					"tile_id": tile_id,
					"rotation": rotation,
					"rotated_connections": rotated_connections
				})

			rotated_connections = rotate_connections(rotated_connections)

	if connection_tiles.is_empty():
		push_error("No valid wire tiles found.")
		return false

	return true

func generate_wire():
	grid.clear()

	var source_id := grid.tile_set.get_source_id(0)
	var start_pos: Vector2i = grid.source.coordinate
	var end_pos: Vector2i = grid.destination.coordinate

	var path: Array[Vector2i] = pathfinder.generate_path(
		grid.size,
		grid.waypoint_count,
		start_pos,
		end_pos
	)

	if path.is_empty():
		push_warning("WirePathfinder did not generate a path.")
		return

	place_path(path, source_id, start_pos, end_pos)
	fill_remaining_cells(path, source_id)
	scramble_path(path)
	
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
			required_connections |= get_direction(cell, start_pos)
		else:
			required_connections |= get_direction(cell, path[i - 1])

		if i == path.size() - 1:
			required_connections |= get_direction(cell, end_pos)
		else:
			required_connections |= get_direction(cell, path[i + 1])

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
			grid.get_rotation_transform(rotation)
		)

func fill_remaining_cells(
	path: Array[Vector2i],
	source_id: int
):
	var path_cells := {}

	for cell in path:
		path_cells[cell] = true

	var valid_tiles: Array[Vector2i] = []
	var atlas := grid.tile_set.get_source(source_id) as TileSetAtlasSource

	if atlas == null:
		return

	for i in range(atlas.get_tiles_count()):
		var tile_id := atlas.get_tile_id(i)
		var tile_data := atlas.get_tile_data(tile_id, 0)

		if tile_data == null:
			continue

		var is_on: bool = tile_data.get_custom_data("IsOn")

		if not is_on:
			valid_tiles.append(tile_id)

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
				grid.get_rotation_transform(rotation)
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

	if connections & TOP:
		count += 1
	if connections & RIGHT:
		count += 1
	if connections & BOTTOM:
		count += 1
	if connections & LEFT:
		count += 1

	return count

func get_direction(from: Vector2i, to: Vector2i) -> int:
	var direction := to - from

	if direction == Vector2i(0, -1):
		return TOP
	if direction == Vector2i(1, 0):
		return RIGHT
	if direction == Vector2i(0, 1):
		return BOTTOM
	if direction == Vector2i(-1, 0):
		return LEFT

	return 0

func rotate_connections(connections: int) -> int:
	var result := 0

	if connections & TOP:
		result |= RIGHT
	if connections & RIGHT:
		result |= BOTTOM
	if connections & BOTTOM:
		result |= LEFT
	if connections & LEFT:
		result |= TOP

	return result

func scramble_path(path: Array[Vector2i]):
	for cell in path:
		var tile_id := grid.get_cell_atlas_coords(cell)
		var source_id := grid.get_cell_source_id(cell)

		var rotation := randi_range(0, 3)

		grid.set_cell(
			cell,
			source_id,
			tile_id,
			grid.get_rotation_transform(rotation)
		)
