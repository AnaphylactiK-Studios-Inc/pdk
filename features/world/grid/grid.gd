@tool
extends Node3D
class_name Grid

signal grid_changed

@export var width: int = 10:
	set(value):
		var new_width := maxi(1, value)

		if new_width == width:
			return

		width = new_width
		_rebuild_if_initialized()

@export var length: int = 10:
	set(value):
		var new_length := maxi(1, value)

		if new_length == length:
			return

		length = new_length
		_rebuild_if_initialized()

@export var cell_size: float = 4.0

@export var cells: Array[GridCell] = []

var _initialized: bool = false

func _ready() -> void:
	ensure_initialized()

func ensure_initialized() -> void:
	if not _initialized or cells.size() != width * length:
		initialize_grid()

func _rebuild_if_initialized() -> void:
	if not _initialized:
		return

	initialize_grid()

func initialize_grid() -> void:
	_initialized = true

	var old_cells := {}

	for cell in cells:
		if cell != null:
			old_cells[cell.grid_position] = cell

	cells.clear()

	for x in range(width):
		for z in range(length):
			var grid_position := Vector2i(x, z)
			var cell: GridCell

			if old_cells.has(grid_position):
				cell = old_cells[grid_position]
			else:
				cell = GridCell.new()
				cell.grid_position = grid_position
				cell.initialize()

			# Without this, two instances of a scene containing this grid
			# share the same cell resources and painting one edits both.
			cell.resource_local_to_scene = true

			cells.append(cell)

	grid_changed.emit()

func is_valid_position(grid_position: Vector2i) -> bool:
	return (
		grid_position.x >= 0 and grid_position.x < width
		and grid_position.y >= 0 and grid_position.y < length
	)

func get_cell_index(grid_position: Vector2i) -> int:
	if not is_valid_position(grid_position):
		return -1

	return grid_position.x * length + grid_position.y

func get_cell(grid_position: Vector2i) -> GridCell:
	var index := get_cell_index(grid_position)

	if index < 0 or index >= cells.size():
		return null

	var cell := cells[index]

	if cell != null and cell.grid_position == grid_position:
		return cell

	return _find_cell_by_scan(grid_position)

func _find_cell_by_scan(grid_position: Vector2i) -> GridCell:
	for cell in cells:
		if cell != null and cell.grid_position == grid_position:
			return cell

	return null

func world_to_grid(world_position: Vector3) -> Vector2i:
	var local_position := to_local(world_position)

	return Vector2i(
		floori(local_position.x / cell_size),
		floori(local_position.z / cell_size)
	)

func grid_to_world(grid_position: Vector2i) -> Vector3:
	return to_global(
		Vector3(
			(grid_position.x + 0.5) * cell_size,
			0.0,
			(grid_position.y + 0.5) * cell_size
		)
	)
