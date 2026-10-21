extends Sprite2D
class_name WireGridEndpoint

@export var coordinate: Vector2i = Vector2i.ZERO:
	set(value):
		coordinate = value
		update_position()

@export var grid: WireGrid

func _ready():
	update_position()

func update_position():
	if not is_inside_tree() or grid == null:
		return

	global_position = grid.to_global(
		grid.map_to_local(coordinate)
	)
