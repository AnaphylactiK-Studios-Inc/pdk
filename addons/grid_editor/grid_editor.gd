@tool
extends EditorPlugin

var toolbar: HBoxContainer
var mode_button: OptionButton

var selected_grid: Grid

var grid_visual: MeshInstance3D
var cell_visuals: Node3D

var is_painting: bool = false
var paint_value: bool = false
var painted_cells: Dictionary = {}

func _enter_tree() -> void:
	create_toolbar()

	var selection := get_editor_interface().get_selection()

	if not selection.selection_changed.is_connected(
		_on_selection_changed
	):
		selection.selection_changed.connect(
			_on_selection_changed
		)

	_on_selection_changed()

func _exit_tree() -> void:
	var selection := get_editor_interface().get_selection()

	if selection.selection_changed.is_connected(
		_on_selection_changed
	):
		selection.selection_changed.disconnect(
			_on_selection_changed
	)

	disconnect_grid()

	if toolbar:
		remove_control_from_container(
			CONTAINER_SPATIAL_EDITOR_MENU,
			toolbar
		)

		toolbar.queue_free()

	clear_visuals()

	selected_grid = null

func _handles(object: Object) -> bool:
	return object is Grid

## The selected grid can be freed out from under us when its scene is closed,
## so every entry point re-validates rather than trusting the stored pointer.
func has_grid() -> bool:
	return is_instance_valid(selected_grid)

func _on_selection_changed() -> void:
	var selection := get_editor_interface().get_selection()
	var selected_nodes := selection.get_selected_nodes()

	var next_grid: Grid = null

	if not selected_nodes.is_empty() and selected_nodes[0] is Grid:
		next_grid = selected_nodes[0] as Grid

	if next_grid == selected_grid and has_grid():
		return

	disconnect_grid()
	clear_visuals()
	stop_painting()

	selected_grid = next_grid

	if not has_grid():
		return

	if not selected_grid.grid_changed.is_connected(on_grid_changed):
		selected_grid.grid_changed.connect(on_grid_changed)

	create_grid_visual()
	create_cell_visuals()

func disconnect_grid() -> void:
	if not has_grid():
		return

	if selected_grid.grid_changed.is_connected(on_grid_changed):
		selected_grid.grid_changed.disconnect(on_grid_changed)

## The grid rebuilt itself (a width/length change in the inspector), so the
## existing visuals describe an extent that no longer exists.
func on_grid_changed() -> void:
	if not has_grid():
		return

	clear_visuals()
	create_grid_visual()
	create_cell_visuals()

func create_toolbar() -> void:
	toolbar = HBoxContainer.new()
	toolbar.name = "GridEditorToolbar"

	var label := Label.new()
	label.text = "Grid Mode:"
	toolbar.add_child(label)

	mode_button = OptionButton.new()
	mode_button.name = "GridModeButton"

	populate_mode_button()

	mode_button.item_selected.connect(
		_on_mode_changed
	)

	toolbar.add_child(mode_button)

	var toggle_on_button := Button.new()
	toggle_on_button.name = "ToggleAllOnButton"
	toggle_on_button.text = "Toggle All On"

	toggle_on_button.pressed.connect(
		toggle_all_on
	)

	toolbar.add_child(toggle_on_button)

	var toggle_off_button := Button.new()
	toggle_off_button.name = "ToggleAllOffButton"
	toggle_off_button.text = "Toggle All Off"

	toggle_off_button.pressed.connect(
		toggle_all_off
	)

	toolbar.add_child(toggle_off_button)

	var refresh_button := Button.new()
	refresh_button.name = "RefreshButton"
	refresh_button.text = "Refresh"

	refresh_button.pressed.connect(
		refresh
	)

	toolbar.add_child(refresh_button)

	add_control_to_container(
		CONTAINER_SPATIAL_EDITOR_MENU,
		toolbar
	)

func populate_mode_button() -> void:
	for property in CellProperty.get_all():
		mode_button.add_item(
			CellProperty.get_display_name(property),
			property
		)

	mode_button.select(0)

## Returns -1 when nothing valid is selected. Callers must bail on -1:
## get_item_id(-1) also returns -1, which would otherwise be read as a
## negative array index and silently resolve to the last property.
func get_selected_property() -> int:
	if mode_button == null or mode_button.selected < 0:
		return -1

	var property := mode_button.get_item_id(
		mode_button.selected
	)

	if not CellProperty.is_valid(property):
		return -1

	return property

func _on_mode_changed(_index: int) -> void:
	if not has_grid():
		return

	update_cell_visuals()

func clear_visuals() -> void:
	if is_instance_valid(grid_visual):
		grid_visual.queue_free()

	grid_visual = null

	if is_instance_valid(cell_visuals):
		cell_visuals.queue_free()

	cell_visuals = null

func create_grid_visual() -> void:
	if not has_grid():
		return

	if is_instance_valid(grid_visual):
		grid_visual.queue_free()

	grid_visual = MeshInstance3D.new()
	grid_visual.name = "GridVisual"

	selected_grid.add_child(grid_visual)

	var mesh := ImmediateMesh.new()
	grid_visual.mesh = mesh

	mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	for x in range(selected_grid.width + 1):
		var x_position := x * selected_grid.cell_size

		mesh.surface_add_vertex(
			Vector3(x_position, 0, 0)
		)

		mesh.surface_add_vertex(
			Vector3(
				x_position,
				0,
				selected_grid.length * selected_grid.cell_size
			)
		)

	for z in range(selected_grid.length + 1):
		var z_position := z * selected_grid.cell_size

		mesh.surface_add_vertex(
			Vector3(0, 0, z_position)
		)

		mesh.surface_add_vertex(
			Vector3(
				selected_grid.width * selected_grid.cell_size,
				0,
				z_position
			)
		)

	mesh.surface_end()

func create_cell_visuals() -> void:
	if not has_grid():
		return

	if is_instance_valid(cell_visuals):
		cell_visuals.queue_free()

	cell_visuals = Node3D.new()
	cell_visuals.name = "CellVisuals"

	selected_grid.add_child(cell_visuals)

	for x in range(selected_grid.width):
		for z in range(selected_grid.length):
			create_cell_visual(Vector2i(x, z))

func create_cell_visual(grid_position: Vector2i) -> void:
	var cell_node := Node3D.new()

	cell_node.name = "Cell_%d_%d" % [
		grid_position.x,
		grid_position.y
	]

	cell_node.position = Vector3(
		(grid_position.x + 0.5) * selected_grid.cell_size,
		0.05,
		(grid_position.y + 0.5) * selected_grid.cell_size
	)

	cell_visuals.add_child(cell_node)
	add_cell_fill(cell_node)
	update_cell_visual(grid_position)

func update_cell_visual(grid_position: Vector2i) -> void:
	if not has_grid():
		return

	if not is_instance_valid(cell_visuals):
		return

	var property := get_selected_property()

	if property < 0:
		return

	var cell := selected_grid.get_cell(grid_position)

	if cell == null:
		return

	var cell_node := cell_visuals.get_node_or_null(
		"Cell_%d_%d" % [
			grid_position.x,
			grid_position.y
		]
	)

	if cell_node == null:
		return

	var fill := cell_node.get_node_or_null("Fill")

	if fill == null:
		return

	fill.visible = cell.has_property(property)

func update_cell_visuals() -> void:
	if not has_grid():
		return

	if not is_instance_valid(cell_visuals):
		return

	for x in range(selected_grid.width):
		for z in range(selected_grid.length):
			update_cell_visual(Vector2i(x, z))

func add_cell_fill(parent: Node3D) -> void:
	var fill := MeshInstance3D.new()
	fill.name = "Fill"

	var mesh := QuadMesh.new()
	mesh.size = Vector2(
		selected_grid.cell_size,
		selected_grid.cell_size
	)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(
		0.3,
		0.6,
		1.0,
		0.25
	)

	fill.mesh = mesh
	fill.material_override = material

	fill.rotation_degrees.x = -90.0

	parent.add_child(fill)

func _forward_3d_gui_input(
	camera: Camera3D,
	event: InputEvent
) -> int:
	if not has_grid():
		stop_painting()

		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				painted_cells.clear()

				var grid_position := get_grid_position_from_mouse(
					camera,
					event.position
				)

				if selected_grid.is_valid_position(grid_position):
					var cell := selected_grid.get_cell(grid_position)
					var property := get_selected_property()

					if cell != null and property >= 0:
						paint_value = not cell.has_property(
							property
						)

						is_painting = true

						paint_cell(
							camera,
							event.position
						)

						return EditorPlugin.AFTER_GUI_INPUT_STOP

			else:
				stop_painting()

				return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseMotion:
		if is_painting:
			# The release event is only forwarded while the cursor is over
			# the 3D viewport. Releasing anywhere else would otherwise leave
			# is_painting set and keep painting with no button held.
			if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
				stop_painting()

				return EditorPlugin.AFTER_GUI_INPUT_PASS

			paint_cell(
				camera,
				event.position
			)

			return EditorPlugin.AFTER_GUI_INPUT_STOP

	return EditorPlugin.AFTER_GUI_INPUT_PASS

func stop_painting() -> void:
	is_painting = false
	painted_cells.clear()

func get_grid_position_from_mouse(
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector2i:
	var ray_origin := camera.project_ray_origin(
		mouse_position
	)

	var ray_direction := camera.project_ray_normal(
		mouse_position
	)

	if absf(ray_direction.y) < 0.001:
		return Vector2i(-1, -1)

	var grid_y := selected_grid.global_position.y

	var distance := (
		grid_y - ray_origin.y
	) / ray_direction.y

	if distance < 0:
		return Vector2i(-1, -1)

	var hit_position := (
		ray_origin
		+ ray_direction * distance
	)

	return selected_grid.world_to_grid(
		hit_position
	)

func paint_cell(
	camera: Camera3D,
	mouse_position: Vector2
) -> void:
	var grid_position := get_grid_position_from_mouse(
		camera,
		mouse_position
	)

	if not selected_grid.is_valid_position(grid_position):
		return

	var cell := selected_grid.get_cell(grid_position)

	if cell == null:
		return

	var cell_key := "%d_%d" % [
		grid_position.x,
		grid_position.y
	]

	if painted_cells.has(cell_key):
		return

	painted_cells[cell_key] = true

	set_cell_value(
		grid_position,
		paint_value
	)

func set_cell_value(
	grid_position: Vector2i,
	value: bool
) -> void:
	if not has_grid():
		return

	var cell := selected_grid.get_cell(grid_position)

	if cell == null:
		return

	var property := get_selected_property()

	if property < 0:
		return

	var old_properties := cell.properties.duplicate()
	var new_properties := cell.properties.duplicate()

	new_properties[CellProperty.get_key(property)] = value

	if old_properties == new_properties:
		return

	var undo_redo := get_undo_redo()

	undo_redo.create_action(
		"Paint Grid Cell"
	)

	undo_redo.add_do_property(
		cell,
		"properties",
		new_properties
	)

	undo_redo.add_undo_property(
		cell,
		"properties",
		old_properties
	)

	undo_redo.add_do_method(
		self,
		"update_cell_visual",
		grid_position
	)

	undo_redo.add_undo_method(
		self,
		"update_cell_visual",
		grid_position
	)

	undo_redo.commit_action()

	get_editor_interface().mark_scene_as_unsaved()

func toggle_cell(grid_position: Vector2i) -> void:
	if not has_grid():
		return

	var cell := selected_grid.get_cell(grid_position)

	if cell == null:
		return

	var property := get_selected_property()

	if property < 0:
		return

	set_cell_value(
		grid_position,
		not cell.has_property(property)
	)

func refresh() -> void:
	if not has_grid():
		return

	var selected_property := get_selected_property()

	mode_button.clear()
	populate_mode_button()

	var new_index := mode_button.get_item_index(
		selected_property
	)

	if new_index >= 0:
		mode_button.select(new_index)

	clear_visuals()
	create_grid_visual()
	create_cell_visuals()

func toggle_all_on() -> void:
	set_all_cells(true)

func toggle_all_off() -> void:
	set_all_cells(false)

func set_all_cells(value: bool) -> void:
	if not has_grid():
		return

	var property := get_selected_property()

	if property < 0:
		return

	var property_key := CellProperty.get_key(property)

	# `cells` is an exported array that can be hand-edited, so null entries
	# are possible; gather the cells actually worth writing to first.
	var targets: Array[GridCell] = []
	var old_properties: Array[Dictionary] = []
	var new_properties: Array[Dictionary] = []

	for cell in selected_grid.cells:
		if cell == null:
			continue

		var updated := cell.properties.duplicate()
		updated[property_key] = value

		if updated == cell.properties:
			continue

		targets.append(cell)
		old_properties.append(cell.properties.duplicate())
		new_properties.append(updated)

	if targets.is_empty():
		return

	var undo_redo := get_undo_redo()

	undo_redo.create_action(
		"Set All Grid Cells"
	)

	for i in range(targets.size()):
		undo_redo.add_do_property(
			targets[i],
			"properties",
			new_properties[i]
		)

		undo_redo.add_undo_property(
			targets[i],
			"properties",
			old_properties[i]
		)

	undo_redo.add_do_method(
		self,
		"update_cell_visuals"
	)

	undo_redo.add_undo_method(
		self,
		"update_cell_visuals"
	)

	undo_redo.commit_action()

	get_editor_interface().mark_scene_as_unsaved()
