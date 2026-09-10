@tool
extends RefCounted
class_name CellProperty

enum Type {
	WALKABLE,
	ENEMY_SPAWN
}

static func get_all() -> Array:
	return Type.values()

static func get_display_name(property: Type) -> String:
	return Type.keys()[property]

static func get_key(property: Type) -> String:
	return Type.keys()[property]
