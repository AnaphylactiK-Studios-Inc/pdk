class_name ControlsHint
extends CanvasLayer

const SOURCE_GROUP := "controls_hint_source"

const STICK_NAMES := {
	JOY_AXIS_LEFT_X: "Left Stick",
	JOY_AXIS_LEFT_Y: "Left Stick",
	JOY_AXIS_RIGHT_X: "Right Stick",
	JOY_AXIS_RIGHT_Y: "Right Stick",
}

@export var key_color: Color = Color(1.0, 0.86, 0.35, 1.0)

@onready var panel: PanelContainer = %Panel
@onready var rows: GridContainer = %Rows

var _source: Node


func _ready() -> void:
	SettingsManager.input_family_changed.connect(_rebuild)
	SettingsManager.keybinds_changed.connect(_rebuild)
	SettingsManager.controller_style_changed.connect(_rebuild)
	_rebuild()


## Polled rather than signalled, so switching characters needs no extra wiring.
func _process(_delta: float) -> void:
	var source := _find_active_source()
	if source != _source:
		_source = source
		_rebuild()


func _find_active_source() -> Node:
	var best: Node = null
	var best_priority := -INF
	for node in get_tree().get_nodes_in_group(SOURCE_GROUP):
		if not node.is_controls_active():
			continue
		var priority: float = node.get(&"controls_hint_priority") if &"controls_hint_priority" in node else 0.0
		if priority > best_priority:
			best = node
			best_priority = priority
	return best


func _rebuild() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()

	if _source == null or not is_instance_valid(_source):
		panel.visible = false
		return

	var family := SettingsManager.active_input_family
	for hint: Dictionary in _source.get_control_hints():
		var keys := _describe_hint(hint, family)
		if keys.is_empty():
			continue  # Unbound on this device.
		_add_row(hint["label"], keys)

	panel.visible = rows.get_child_count() > 0


func _describe_hint(hint: Dictionary, family: int) -> String:
	var override_key := "joy" if family == SettingsManager.BindFamily.JOY else "kbm"
	if hint.has(override_key):
		return hint[override_key]

	var parts := PackedStringArray()
	for action: String in hint["actions"]:
		var event := SettingsManager.get_event_for_family(action, family)
		if event == null:
			continue
		var text := _describe_event(event)
		if not parts.has(text):
			parts.append(text)
	return "/".join(parts)


## Four stick directions read better as one "Left Stick" than as four halves.
func _describe_event(event: InputEvent) -> String:
	if event is InputEventJoypadMotion and STICK_NAMES.has(event.axis):
		return STICK_NAMES[event.axis]
	return SettingsManager.describe_event(event)


func _add_row(label_text: String, keys: String) -> void:
	var label := Label.new()
	label.text = label_text
	rows.add_child(label)

	var key := Label.new()
	key.text = keys
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key.add_theme_color_override("font_color", key_color)
	rows.add_child(key)
