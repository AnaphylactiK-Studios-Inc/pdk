extends Node
class_name GridWalkability

@export var grid: Grid

func is_walkable(grid_position: Vector2i) -> bool:
	if grid == null:
		return false

	var cell := grid.get_cell(grid_position)
	if cell == null:
		return false

	return cell.has_property(
		CellProperty.Type.WALKABLE
	)

func can_enter(grid_position: Vector2i) -> bool:
	return is_walkable(grid_position)

func get_adjacent_cells(
	grid_position: Vector2i
) -> Array[Vector2i]:
	var adjacent_cells: Array[Vector2i] = [
		grid_position + Vector2i.UP,
		grid_position + Vector2i.DOWN,
		grid_position + Vector2i.LEFT,
		grid_position + Vector2i.RIGHT
	]

	var valid_cells: Array[Vector2i] = []

	for position in adjacent_cells:
		if grid.is_valid_position(position):
			valid_cells.append(position)

	return valid_cells

func get_adjacent_walkable_cells(
	grid_position: Vector2i
) -> Array[Vector2i]:
	var adjacent_cells := get_adjacent_cells(
		grid_position
	)

	var walkable_cells: Array[Vector2i] = []

	for position in adjacent_cells:
		if is_walkable(position):
			walkable_cells.append(position)

	return walkable_cells
