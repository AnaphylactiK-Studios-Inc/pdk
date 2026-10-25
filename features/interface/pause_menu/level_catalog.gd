class_name LevelCatalog
extends RefCounted

## Levels the pause menu's Level Select offers. For now this is every test
## scene; swap entries out for real levels as they get built.
const LEVELS := [
	{"name": "Base Test", "path": "res://features/tests/base_test_scene.tscn"},
	{"name": "Circuitry Test", "path": "res://features/tests/circuitry_test_scene.tscn"},
	{"name": "DK Movement", "path": "res://features/tests/dk_movement_scene.tscn"},
	{"name": "Switch Characters", "path": "res://features/tests/switch_characters_scene.tscn"},
	{"name": "Wire Grid Puzzle", "path": "res://features/tests/wire_grid_puzzle_scene.tscn"},
]
