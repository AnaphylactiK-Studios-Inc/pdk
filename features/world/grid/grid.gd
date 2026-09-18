@tool
extends Node3D
class_name Grid

@export var width: int = 10
@export var length: int = 10
@export var cell_size: float = 4.0

@export var cells: Array[GridCell] = []

func _ready() -> void:
	if cells.size() != width * length:
		initialize_grid()

func initialize_grid() -> void:
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

			cells.append(cell)

func is_valid_position(grid_position: Vector2i) -> bool:
	return (
		grid_position.x >= 0 and grid_position.x < width
		and grid_position.y >= 0 and grid_position.y < length
	)

func get_cell(grid_position: Vector2i) -> GridCell:
	if not is_valid_position(grid_position):
		return null

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
