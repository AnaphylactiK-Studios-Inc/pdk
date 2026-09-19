extends CanvasLayer

const PLAYER_GROUP := "grid_player"

@export_group("Wiring")
@export var grid_walkability: GridWalkability
@export var player: Node3D

@export_group("Layout")
@export var max_size: Vector2 = Vector2(180.0, 180.0)
@export var screen_margin: float = 16.0
@export var padding: float = 6.0

@export_group("Appearance")
@export var panel_color: Color = Color(0.05, 0.06, 0.09, 0.78)
@export var border_color: Color = Color(0.55, 0.62, 0.75, 0.55)
@export var unwalkable_color: Color = Color(0.16, 0.18, 0.23, 0.55)
@export var walkable_color: Color = Color(0.36, 0.62, 0.95, 0.85)
@export var player_color: Color = Color(1.0, 0.86, 0.35, 1.0)
## Keeps the marker readable where it overlaps a bright walkable tile.
@export var player_outline_color: Color = Color(0.09, 0.07, 0.03, 0.9)
## Shrinks each drawn tile so neighbouring cells read as separate squares.
@export var cell_inset: float = 1.0

var _view: Control
var _grid: Grid
var _cell_pixels: float = 0.0
var _map_pixels: Vector2 = Vector2.ZERO

var _last_player_cell: Vector2 = Vector2.INF
var _last_player_facing: float = INF

func _ready() -> void:
	_view = $MinimapView
	_view.draw.connect(_on_view_draw)

	resolve_references()

	if _grid != null and not _grid.grid_changed.is_connected(_on_grid_changed):
		_grid.grid_changed.connect(_on_grid_changed)

	_update_layout()


func resolve_references() -> void:
	if grid_walkability == null:
		grid_walkability = _find_first_walkability(_scene_root())

	if grid_walkability == null:
		grid_walkability = _find_first_walkability(get_tree().current_scene)

	if grid_walkability == null:
		push_warning(
			"Minimap: no GridWalkability found; minimap hidden."
		)

		visible = false

		return

	_grid = grid_walkability.grid

	if _grid == null:
		push_warning(
			"Minimap: GridWalkability has no grid; minimap hidden."
		)

		visible = false

		return

	_grid.ensure_initialized()

	if player == null:
		player = _find_player()

	visible = true

func _scene_root() -> Node:
	var node: Node = self
	var tree_root := get_tree().root

	while node.get_parent() != null and node.get_parent() != tree_root:
		node = node.get_parent()

	return node

func _find_first_walkability(node: Node) -> GridWalkability:
	if node == null:
		return null

	if node is GridWalkability:
		return node as GridWalkability

	for child in node.get_children():
		var found := _find_first_walkability(child)

		if found != null:
			return found

	return null

func _find_player() -> Node3D:
	var candidates := get_tree().get_nodes_in_group(PLAYER_GROUP)

	for candidate in candidates:
		if candidate is Node3D:
			return candidate as Node3D

	return null

func _on_grid_changed() -> void:
	_update_layout()

func _update_layout() -> void:
	if _grid == null or _view == null:
		return

	if _grid.width <= 0 or _grid.length <= 0:
		return

	_cell_pixels = minf(
		max_size.x / float(_grid.width),
		max_size.y / float(_grid.length)
	)

	_map_pixels = Vector2(
		float(_grid.width),
		float(_grid.length)
	) * _cell_pixels

	var panel_size := _map_pixels + Vector2(padding, padding) * 2.0

	_view.anchor_left = 1.0
	_view.anchor_right = 1.0
	_view.anchor_top = 0.0
	_view.anchor_bottom = 0.0

	_view.offset_left = -(panel_size.x + screen_margin)
	_view.offset_right = -screen_margin
	_view.offset_top = screen_margin
	_view.offset_bottom = screen_margin + panel_size.y

	_view.queue_redraw()

func _process(_delta: float) -> void:
	if not visible or _grid == null or _view == null:
		return

	var cell := get_player_cell()
	var facing := get_player_facing()

	if cell.is_equal_approx(_last_player_cell) and is_equal_approx(facing, _last_player_facing):
		return

	_last_player_cell = cell
	_last_player_facing = facing

	_view.queue_redraw()

func get_player_cell() -> Vector2:
	if player == null or _grid == null or not player.is_inside_tree():
		return Vector2.INF

	var local := _grid.to_local(player.global_position)

	return Vector2(local.x, local.z) / _grid.cell_size

func get_player_facing() -> float:
	if player == null or not player.is_inside_tree():
		return INF

	var forward := -player.global_transform.basis.z

	return atan2(forward.x, -forward.z)

func _on_view_draw() -> void:
	if _grid == null or _cell_pixels <= 0.0:
		return

	var panel := Rect2(Vector2.ZERO, _view.size)

	_view.draw_rect(panel, panel_color, true)
	_view.draw_rect(panel, border_color, false, 1.0)

	var origin := Vector2(padding, padding)

	_view.draw_rect(
		Rect2(origin, _map_pixels),
		unwalkable_color,
		true
	)

	for x in range(_grid.width):
		for z in range(_grid.length):
			var cell_position := Vector2i(x, z)

			if not grid_walkability.is_walkable(cell_position):
				continue

			var top_left := origin + Vector2(
				float(x) * _cell_pixels,
				float(z) * _cell_pixels
			)

			_view.draw_rect(
				Rect2(
					top_left + Vector2(cell_inset, cell_inset),
					Vector2(
						_cell_pixels - cell_inset * 2.0,
						_cell_pixels - cell_inset * 2.0
					)
				),
				walkable_color,
				true
			)

	_draw_player_marker(origin)

func _draw_player_marker(origin: Vector2) -> void:
	var cell := get_player_cell()

	if not _is_finite(cell):
		return

	var centre := origin + cell * _cell_pixels
	var facing := get_player_facing()

	if not is_finite(facing):
		_view.draw_circle(centre, _cell_pixels * 0.35, player_color)
		return

	# Arrowhead shape for player marker
	var tip := maxf(_cell_pixels * 0.95, 6.0)
	var tail := maxf(_cell_pixels * 0.65, 4.5)

	var points := PackedVector2Array([
		centre + Vector2.UP.rotated(facing) * tip,
		centre + Vector2.UP.rotated(facing + TAU * 0.38) * tail,
		centre + Vector2.UP.rotated(facing - TAU * 0.38) * tail
	])

	_view.draw_colored_polygon(points, player_color)

	var outline := points.duplicate()
	outline.append(points[0])

	_view.draw_polyline(outline, player_outline_color, 1.0)

func _is_finite(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
