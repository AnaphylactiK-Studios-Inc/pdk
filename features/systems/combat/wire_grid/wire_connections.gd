extends Node
class_name WireConnections

var grid: WireGrid

var on_cells: Dictionary = {}
var original_tiles: Dictionary = {}
var on_tiles: Dictionary = {}
var off_tiles: Dictionary = {}

const TOP := 1
const RIGHT := 2
const BOTTOM := 4
const LEFT := 8

func initialize():
	if grid == null:
		grid = get_parent() as WireGrid

	if grid == null:
		push_error("WireConnections requires a WireGrid.")
		return

	build_tile_lookup()
	remember_original_tiles()
	update_connections()

func build_tile_lookup():
	on_tiles.clear()
	off_tiles.clear()

	var source_id := grid.tile_set.get_source_id(0)
	var atlas := grid.tile_set.get_source(source_id) as TileSetAtlasSource

	if atlas == null:
		push_error("No TileSetAtlasSource found.")
		return

	for i in range(atlas.get_tiles_count()):
		var tile_id := atlas.get_tile_id(i)
		var tile_data := atlas.get_tile_data(tile_id, 0)

		if tile_data == null:
			continue

		var connections: int = tile_data.get_custom_data("Connections")
		var is_on: bool = tile_data.get_custom_data("IsOn")

		if is_on:
			on_tiles[connections] = tile_id
		else:
			off_tiles[connections] = tile_id

func remember_original_tiles():
	original_tiles.clear()

	for cell in get_all_cells():
		var tile_id := grid.get_cell_atlas_coords(cell)

		if tile_id == Vector2i(-1, -1):
			continue

		var source_id := grid.get_cell_source_id(cell)
		var tile_data := get_tile_data(tile_id, source_id)

		if tile_data == null:
			continue

		var is_on: bool = tile_data.get_custom_data("IsOn")

		if not is_on:
			original_tiles[cell] = tile_id

func update_connections():
	refresh_cell_connections()

	var new_on_cells := {}
	var start_cell := get_start_cell()

	if is_inside_grid(start_cell):
		var source_direction := get_source_direction()
		var source_connections: int = grid.cell_connections.get(start_cell, 0)

		if source_direction != 0 and has_connection(source_connections, source_direction):
			new_on_cells[start_cell] = true

	var changed := true

	while changed:
		changed = false

		for cell in get_all_cells():
			if not new_on_cells.has(cell):
				continue

			var connections: int = grid.cell_connections.get(cell, 0)

			for direction in [TOP, RIGHT, BOTTOM, LEFT]:
				if not has_connection(connections, direction):
					continue

				var neighbor := get_neighbor(cell, direction)

				if not is_inside_grid(neighbor):
					continue

				if not are_connected(cell, neighbor, direction):
					continue

				if not new_on_cells.has(neighbor):
					new_on_cells[neighbor] = true
					changed = true

	on_cells = new_on_cells

	update_tile_visuals()
	update_destination_power()

func update_destination_power():
	if grid.destination == null:
		return

	var destination_cell: Vector2i = grid.destination.coordinate
	var powered := false
	var direction := 0

	if destination_cell.x == -1:
		direction = LEFT
	elif destination_cell.x == grid.size:
		direction = RIGHT
	elif destination_cell.y == -1:
		direction = TOP
	elif destination_cell.y == grid.size:
		direction = BOTTOM

	if direction != 0:
		var neighbor := destination_cell - get_neighbor(Vector2i.ZERO, direction)

		if on_cells.has(neighbor):
			var connections: int = grid.cell_connections.get(neighbor, 0)
			powered = has_connection(connections, direction)
	else:
		powered = on_cells.has(destination_cell)

	grid.destination.powered = powered

func get_source_direction() -> int:
	if grid.source == null:
		return 0

	var source_pos: Vector2i = grid.source.coordinate

	if source_pos.x == -1:
		return LEFT
	if source_pos.x == grid.size:
		return RIGHT
	if source_pos.y == -1:
		return TOP
	if source_pos.y == grid.size:
		return BOTTOM

	return 0

func refresh_cell_connections():
	grid.cell_connections.clear()

	for cell in get_all_cells():
		grid.cell_connections[cell] = get_current_connections(cell)

func get_current_connections(cell: Vector2i) -> int:
	var tile_id := grid.get_cell_atlas_coords(cell)

	if tile_id == Vector2i(-1, -1):
		return 0

	var source_id := grid.get_cell_source_id(cell)
	var tile_data := get_tile_data(tile_id, source_id)

	if tile_data == null:
		return 0

	var connections: int = tile_data.get_custom_data("Connections")
	var rotation := get_cell_rotation(cell)

	for i in range(rotation):
		connections = rotate_connections(connections)

	return connections

func update_tile_visuals():
	for cell in get_all_cells():
		update_tile_visual(cell, on_cells.has(cell))

func update_tile_visual(cell: Vector2i, is_on: bool):
	if not original_tiles.has(cell):
		return

	var original_tile: Vector2i = original_tiles[cell]
	var source_id := grid.get_cell_source_id(cell)
	var tile_data := get_tile_data(original_tile, source_id)

	if tile_data == null:
		return

	var connections: int = tile_data.get_custom_data("Connections")
	var target_tiles: Dictionary = on_tiles if is_on else off_tiles

	if not target_tiles.has(connections):
		return

	var current_rotation := grid.get_cell_alternative_tile(cell)

	grid.set_cell(
		cell,
		source_id,
		target_tiles[connections],
		current_rotation
	)

func get_tile_data(tile_id: Vector2i, source_id: int) -> TileData:
	if source_id < 0:
		return null

	var atlas := grid.tile_set.get_source(source_id) as TileSetAtlasSource

	if atlas == null:
		return null

	return atlas.get_tile_data(tile_id, 0)

func get_cell_rotation(cell: Vector2i) -> int:
	var alternative_id := grid.get_cell_alternative_tile(cell)

	if alternative_id == 0:
		return 0

	var transpose := alternative_id & TileSetAtlasSource.TRANSFORM_TRANSPOSE
	var flip_h := alternative_id & TileSetAtlasSource.TRANSFORM_FLIP_H
	var flip_v := alternative_id & TileSetAtlasSource.TRANSFORM_FLIP_V

	if transpose != 0 and flip_h != 0:
		return 1

	if flip_h != 0 and flip_v != 0:
		return 2

	if transpose != 0 and flip_v != 0:
		return 3

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

func is_cell_on(cell: Vector2i) -> bool:
	return on_cells.has(cell)

func get_start_cell() -> Vector2i:
	if grid.source == null:
		return Vector2i(-1, -1)

	var start_pos: Vector2i = grid.source.coordinate

	if start_pos.x == -1:
		return Vector2i(0, start_pos.y)

	if start_pos.x == grid.size:
		return Vector2i(grid.size - 1, start_pos.y)

	if start_pos.y == -1:
		return Vector2i(start_pos.x, 0)

	if start_pos.y == grid.size:
		return Vector2i(start_pos.x, grid.size - 1)

	return start_pos

func are_connected(
	cell: Vector2i,
	neighbor: Vector2i,
	direction: int
) -> bool:
	var opposite := get_opposite_direction(direction)
	var cell_connections: int = grid.cell_connections.get(cell, 0)
	var neighbor_connections: int = grid.cell_connections.get(neighbor, 0)

	return (
		has_connection(cell_connections, direction)
		and has_connection(neighbor_connections, opposite)
	)

func has_connection(connections: int, direction: int) -> bool:
	return (connections & direction) != 0

func get_opposite_direction(direction: int) -> int:
	match direction:
		TOP:
			return BOTTOM
		RIGHT:
			return LEFT
		BOTTOM:
			return TOP
		LEFT:
			return RIGHT

	return 0

func get_neighbor(cell: Vector2i, direction: int) -> Vector2i:
	match direction:
		TOP:
			return cell + Vector2i(0, -1)
		RIGHT:
			return cell + Vector2i(1, 0)
		BOTTOM:
			return cell + Vector2i(0, 1)
		LEFT:
			return cell + Vector2i(-1, 0)

	return cell

func is_inside_grid(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.x < grid.size
		and cell.y >= 0
		and cell.y < grid.size
	)

func get_all_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []

	for y in range(grid.size):
		for x in range(grid.size):
			cells.append(Vector2i(x, y))

	return cells
