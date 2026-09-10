@tool
extends EditorPlugin

var toolbar: HBoxContainer
var mode_button: OptionButton

var selected_grid: Grid

var grid_visual: MeshInstance3D
var cell_visuals: Node3D

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

	if toolbar:
		remove_control_from_container(
			CONTAINER_SPATIAL_EDITOR_MENU,
			toolbar
		)

		toolbar.queue_free()

	clear_visuals()

func _handles(object: Object) -> bool:
	return object is Grid

func _on_selection_changed() -> void:
	var selection := get_editor_interface().get_selection()
	var selected_nodes := selection.get_selected_nodes()

	if selected_nodes.is_empty():
		selected_grid = null
		return

	if selected_nodes[0] is Grid:
		selected_grid = selected_nodes[0] as Grid

		clear_visuals()
		create_grid_visual()
		create_cell_visuals()

func create_toolbar() -> void:
	toolbar = HBoxContainer.new()
	toolbar.name = "GridEditorToolbar"
	
	# Grid mode dropdown
	var label := Label.new()
	label.text = "Grid Mode:"
	toolbar.add_child(label)

	mode_button = OptionButton.new()
	mode_button.name = "GridModeButton"

	for property in CellProperty.get_all():
		mode_button.add_item(
			CellProperty.get_display_name(property),
			property
		)

	mode_button.select(0)
	mode_button.item_selected.connect(
		_on_mode_changed
	)

	toolbar.add_child(mode_button)
	
	# Toggle all grid cells "On" button
	var toggle_on_button := Button.new()
	toggle_on_button.name = "ToggleAllOnButton"
	toggle_on_button.text = "Toggle All On"

	toggle_on_button.pressed.connect(
		toggle_all_on
	)

	toolbar.add_child(toggle_on_button)
	
	# Toggle all grid cells "Off" button
	var toggle_off_button := Button.new()
	toggle_off_button.name = "ToggleAllOffButton"
	toggle_off_button.text = "Toggle All Off"

	toggle_off_button.pressed.connect(
		toggle_all_off
	)

	toolbar.add_child(toggle_off_button)

	# Refresh button
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
	
func _on_mode_changed(_index: int) -> void:
	if selected_grid == null:
		return

	update_cell_visuals()

func clear_visuals() -> void:
	if grid_visual:
		grid_visual.queue_free()
		grid_visual = null

	if cell_visuals:
		cell_visuals.queue_free()
		cell_visuals = null

func create_grid_visual() -> void:
	if grid_visual:
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
				selected_grid.height * selected_grid.cell_size
			)
		)

	for z in range(selected_grid.height + 1):
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
	if cell_visuals:
		cell_visuals.queue_free()

	cell_visuals = Node3D.new()
	cell_visuals.name = "CellVisuals"

	selected_grid.add_child(cell_visuals)

	for x in range(selected_grid.width):
		for z in range(selected_grid.height):
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
	if cell_visuals == null:
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

	var property := mode_button.get_item_id(
		mode_button.selected
	)

	var active: bool = cell.has_property(property)

	fill.visible = active

func update_cell_visuals() -> void:
	if selected_grid == null:
		return

	if cell_visuals == null:
		return

	for x in range(selected_grid.width):
		for z in range(selected_grid.height):
			update_cell_visual(Vector2i(x, z))

func add_cell_fill(parent: Node3D) -> void:
	# Fill the cell with a transparent light blue to signify 
	# that the property is toggled True
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
	if selected_grid == null:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseButton:
		if (
			event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		):
			paint_cell(
				camera,
				event.position
			)

			return EditorPlugin.AFTER_GUI_INPUT_STOP

	return EditorPlugin.AFTER_GUI_INPUT_PASS

func paint_cell(
	camera: Camera3D,
	mouse_position: Vector2
) -> void:
	var ray_origin := camera.project_ray_origin(
		mouse_position
	)

	var ray_direction := camera.project_ray_normal(
		mouse_position
	)

	if abs(ray_direction.y) < 0.001:
		return

	var grid_y := selected_grid.global_position.y

	var distance := (
		grid_y - ray_origin.y
	) / ray_direction.y

	if distance < 0:
		return

	var hit_position := (
		ray_origin
		+ ray_direction * distance
	)

	var grid_position := selected_grid.world_to_grid(
		hit_position
	)

	if not selected_grid.is_valid_position(grid_position):
		return

	var cell := selected_grid.get_cell(grid_position)

	if cell == null:
		return

	print("Cell %s Selected" % cell.grid_position)

	toggle_cell(grid_position)

func toggle_cell(grid_position: Vector2i) -> void:
	var cell := selected_grid.get_cell(grid_position)

	if cell == null:
		return

	var property := mode_button.get_item_id(
		mode_button.selected
	)

	var old_properties := cell.properties.duplicate()
	var new_properties := cell.properties.duplicate()

	var property_key := CellProperty.get_key(property)

	var old_value: bool = old_properties.get(
		property_key,
		false
	)

	new_properties[property_key] = not old_value

	var undo_redo := get_undo_redo()

	undo_redo.create_action("Toggle Grid Cell")

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

func refresh() -> void:
	if selected_grid == null:
		return

	var selected_property := 0

	if mode_button.selected >= 0:
		selected_property = mode_button.get_item_id(
			mode_button.selected
		)

	mode_button.clear()

	for property in CellProperty.get_all():
		mode_button.add_item(
			CellProperty.get_display_name(property),
			property
		)

	var new_index := mode_button.get_item_index(
		selected_property
	)

	if new_index >= 0:
		mode_button.select(new_index)
	else:
		mode_button.select(0)

	clear_visuals()
	create_grid_visual()
	create_cell_visuals()

func toggle_all_on() -> void:
	_set_all_cells(true)

func toggle_all_off() -> void:
	_set_all_cells(false)

func _set_all_cells(value: bool) -> void:
	if selected_grid == null:
		return

	var property := mode_button.get_item_id(
		mode_button.selected
	)

	var old_properties: Array[Dictionary] = []
	var new_properties: Array[Dictionary] = []

	for cell in selected_grid.cells:
		old_properties.append(cell.properties.duplicate())

		var properties := cell.properties.duplicate()
		properties[CellProperty.get_key(property)] = value
		new_properties.append(properties)

	var undo_redo := get_undo_redo()

	undo_redo.create_action(
		"Set All Grid Cells"
	)

	for i in range(selected_grid.cells.size()):
		var cell := selected_grid.cells[i]

		undo_redo.add_do_property(
			cell,
			"properties",
			new_properties[i]
		)

		undo_redo.add_undo_property(
			cell,
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
