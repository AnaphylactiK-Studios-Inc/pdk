extends TileMapLayer
class_name WireGrid

const TOP := 1
const RIGHT := 2
const BOTTOM := 4
const LEFT := 8
const DIRECTIONS: Array[int] = [TOP, RIGHT, BOTTOM, LEFT]

const MAX_SCRAMBLE_ATTEMPTS := 10

@export var size := 5
@export var waypoint_count := 2

@export var source: WireGridEndpoint
@export var destination: WireGridEndpoint

var wire_connections: WireConnections

var atlas_source_id := -1
var on_tiles: Dictionary = {}
var off_tiles: Dictionary = {}
var off_tile_connections: Dictionary = {}

func _ready():
	wire_connections = get_node_or_null("WireConnections") as WireConnections

	for endpoint in [source, destination]:
		if endpoint:
			endpoint.grid = self
			endpoint.coordinate = snap_to_edge(endpoint.coordinate)

	if not build_tile_lookup():
		return

	var generator := WireGridGenerator.new(self)
	var path := generator.generate()

	if wire_connections == null:
		return

	wire_connections.grid = self
	wire_connections.initialize()

	var attempts := 0

	while is_solved() and attempts < MAX_SCRAMBLE_ATTEMPTS:
		generator.scramble_path(path)
		wire_connections.refresh_all()
		attempts += 1

func build_tile_lookup() -> bool:
	on_tiles.clear()
	off_tiles.clear()
	off_tile_connections.clear()

	if tile_set == null or tile_set.get_source_count() == 0:
		push_error("WireGrid requires a TileSet with an atlas source.")
		return false

	atlas_source_id = tile_set.get_source_id(0)
	var atlas := tile_set.get_source(atlas_source_id) as TileSetAtlasSource

	if atlas == null:
		push_error("No TileSetAtlasSource found.")
		return false

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
			off_tile_connections[tile_id] = connections

	return true

func is_solved() -> bool:
	return destination != null and destination.powered

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

	if wire_connections:
		wire_connections.update_cell(cell)

func snap_to_edge(coordinate: Vector2i) -> Vector2i:
	if size <= 0:
		return coordinate

	var result := Vector2i(
		clampi(coordinate.x, -1, size),
		clampi(coordinate.y, -1, size)
	)
	var outside_x := result.x == -1 or result.x == size
	var outside_y := result.y == -1 or result.y == size

	if outside_x:
		result.y = clampi(result.y, 0, size - 1)
	elif not outside_y:
		var left := result.x
		var right := size - 1 - result.x
		var top := result.y
		var bottom := size - 1 - result.y
		var nearest := mini(mini(left, right), mini(top, bottom))

		if nearest == left:
			result.x = -1
		elif nearest == right:
			result.x = size
		elif nearest == top:
			result.y = -1
		else:
			result.y = size

	if result != coordinate:
		push_warning(
			"WireGrid: endpoint %s is not on the grid edge; snapped to %s."
			% [coordinate, result]
		)

	return result

## Direction pointing from the endpoint's adjacent cell out to the endpoint.
func get_edge_direction(coordinate: Vector2i) -> int:
	if coordinate.x == -1:
		return LEFT
	if coordinate.x == size:
		return RIGHT
	if coordinate.y == -1:
		return TOP
	if coordinate.y == size:
		return BOTTOM

	return 0

func get_adjacent_cell(coordinate: Vector2i) -> Vector2i:
	return coordinate - get_offset(get_edge_direction(coordinate))

func is_inside_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < size and cell.y >= 0 and cell.y < size

static func get_offset(direction: int) -> Vector2i:
	match direction:
		TOP:
			return Vector2i.UP
		RIGHT:
			return Vector2i.RIGHT
		BOTTOM:
			return Vector2i.DOWN
		LEFT:
			return Vector2i.LEFT

	return Vector2i.ZERO

static func get_direction(from: Vector2i, to: Vector2i) -> int:
	for direction in DIRECTIONS:
		if get_offset(direction) == to - from:
			return direction

	return 0

static func get_opposite_direction(direction: int) -> int:
	return rotate_connections(rotate_connections(direction))

## Rotates connection bits 90 degrees clockwise.
static func rotate_connections(connections: int) -> int:
	return ((connections << 1) | (connections >> 3)) & 15

static func get_tile_rotation(alternative_id: int) -> int:
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

static func get_rotation_transform(rotation: int) -> int:
	match rotation:
		1:
			return TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
		2:
			return TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V
		3:
			return TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V

	return 0
