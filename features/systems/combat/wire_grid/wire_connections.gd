extends Node
class_name WireConnections

var grid: WireGrid

var cell_connections: Dictionary = {}
var on_cells: Dictionary = {}
var original_tiles: Dictionary = {}

func initialize():
	if grid == null:
		grid = get_parent() as WireGrid

	if grid == null:
		push_error("WireConnections requires a WireGrid.")
		return

	remember_original_tiles()
	refresh_all()

func remember_original_tiles():
	original_tiles.clear()

	for cell in get_all_cells():
		var tile_id := grid.get_cell_atlas_coords(cell)

		if grid.off_tile_connections.has(tile_id):
			original_tiles[cell] = tile_id

func refresh_all():
	cell_connections.clear()

	for cell in get_all_cells():
		cell_connections[cell] = get_current_connections(cell)

	update_connections()

func update_cell(cell: Vector2i):
	cell_connections[cell] = get_current_connections(cell)
	update_connections()

func update_connections():
	var powered := {}
	var queue: Array[Vector2i] = []

	if grid.source:
		var start_cell := grid.get_adjacent_cell(grid.source.coordinate)
		var source_direction := grid.get_edge_direction(grid.source.coordinate)

		if grid.is_inside_grid(start_cell) and has_connection(get_connections(start_cell), source_direction):
			powered[start_cell] = true
			queue.append(start_cell)

	var index := 0

	while index < queue.size():
		var cell := queue[index]
		var connections := get_connections(cell)
		index += 1

		for direction in WireGrid.DIRECTIONS:
			if not has_connection(connections, direction):
				continue

			var neighbor: Vector2i = cell + WireGrid.get_offset(direction)

			if powered.has(neighbor) or not grid.is_inside_grid(neighbor):
				continue

			if has_connection(get_connections(neighbor), WireGrid.get_opposite_direction(direction)):
				powered[neighbor] = true
				queue.append(neighbor)

	var previous := on_cells
	on_cells = powered

	for cell in previous:
		if not on_cells.has(cell):
			update_tile_visual(cell, false)

	for cell in on_cells:
		if not previous.has(cell):
			update_tile_visual(cell, true)

	update_destination_power()

func update_destination_power():
	if grid.destination == null:
		return

	var coordinate := grid.destination.coordinate
	var neighbor := grid.get_adjacent_cell(coordinate)
	var direction := grid.get_edge_direction(coordinate)

	grid.destination.powered = (
		on_cells.has(neighbor)
		and has_connection(get_connections(neighbor), direction)
	)

func get_connections(cell: Vector2i) -> int:
	return cell_connections.get(cell, 0)

func get_current_connections(cell: Vector2i) -> int:
	if not original_tiles.has(cell):
		return 0

	var connections: int = grid.off_tile_connections[original_tiles[cell]]
	var rotation := WireGrid.get_tile_rotation(grid.get_cell_alternative_tile(cell))

	for i in range(rotation):
		connections = WireGrid.rotate_connections(connections)

	return connections

func update_tile_visual(cell: Vector2i, is_on: bool):
	if not original_tiles.has(cell):
		return

	var connections: int = grid.off_tile_connections[original_tiles[cell]]
	var target_tiles: Dictionary = grid.on_tiles if is_on else grid.off_tiles

	if not target_tiles.has(connections):
		return

	grid.set_cell(
		cell,
		grid.atlas_source_id,
		target_tiles[connections],
		grid.get_cell_alternative_tile(cell)
	)

func is_cell_on(cell: Vector2i) -> bool:
	return on_cells.has(cell)

func has_connection(connections: int, direction: int) -> bool:
	return (connections & direction) != 0

func get_all_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []

	for y in range(grid.size):
		for x in range(grid.size):
			cells.append(Vector2i(x, y))

	return cells
