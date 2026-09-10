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
	return properties.get(
		CellProperty.get_key(property), 
		false
	)

func set_property(
	property: CellProperty.Type,
	value: bool
) -> void:
	properties[CellProperty.get_key(property)] = value
