extends TileMapLayer
class_name WireGrid

@export var size := 5
@export var waypoint_count := 2

@export var source: WireGridEndpoint
@export var destination: WireGridEndpoint

var cell_connections: Dictionary = {}

func _ready():
	if source:
		source.grid = self
		source.update_position()

	if destination:
		destination.grid = self
		destination.update_position()

	var generator := WireGridGenerator.new(self)
	generator.generate()

	var wire_connections := get_node_or_null("WireConnections") as WireConnections

	if wire_connections:
		wire_connections.grid = self
		wire_connections.initialize()
		
func rotate_cell(cell: Vector2i):
	var tile_id := get_cell_atlas_coords(cell)

	if tile_id == Vector2i(-1, -1):
		return

	var source_id := get_cell_source_id(cell)

	if source_id < 0:
		return

	var alternative_id := get_cell_alternative_tile(cell)
	var rotation := (get_tile_rotation(alternative_id) + 1) % 4

	set_cell(
		cell,
		source_id,
		tile_id,
		get_rotation_transform(rotation)
	)

	var wire_connections := get_node_or_null("WireConnections") as WireConnections

	if wire_connections:
		wire_connections.update_connections()

func get_tile_rotation(alternative_id: int) -> int:
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

func get_rotation_transform(rotation: int) -> int:
	match rotation:
		0:
			return 0
		1:
			return TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
		2:
			return TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V
		3:
			return TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V

	return 0
