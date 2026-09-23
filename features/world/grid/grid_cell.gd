@tool
extends Resource
class_name GridCell

@export var grid_position: Vector2i
@export var properties: Dictionary = {}

func initialize() -> void:
	properties.clear()

	for property in CellProperty.get_all():
		properties[CellProperty.get_key(property)] = false

func has_property(property: CellProperty.Type) -> bool:
	var key := CellProperty.get_key(property)

	if key.is_empty():
		return false

	return properties.get(key, false) == true

func set_property(
	property: CellProperty.Type,
	value: bool
) -> void:
	var key := CellProperty.get_key(property)

	if key.is_empty():
		return

	properties[key] = value
