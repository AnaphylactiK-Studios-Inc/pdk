@tool
extends RefCounted
class_name CellProperty

enum Type {
	WALKABLE,
	ENEMY_SPAWN
}

static func get_all() -> Array:
	return Type.values()

static func is_valid(property: int) -> bool:
	return property >= 0 and property < Type.keys().size()

static func get_display_name(property: Type) -> String:
	return get_key(property)

static func get_key(property: Type) -> String:
	if not is_valid(property):
		push_error(
			"CellProperty: invalid property value %d" % property
		)

		return ""

	return Type.keys()[property]
