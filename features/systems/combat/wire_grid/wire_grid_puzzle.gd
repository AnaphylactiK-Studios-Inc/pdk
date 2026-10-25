extends CanvasLayer
class_name WirePuzzle

const GROUP := &"wire_puzzle"

const CONTROL_HINTS := [
	{"label": "Move Cursor", "actions": ["interface_up", "interface_left", "interface_down", "interface_right"]},
	{"label": "Rotate Tile", "actions": ["interface_accept"]},
	{"label": "Close Puzzle", "actions": ["toggle_wire_puzzle", "interface_cancel"]},
]

var controls_hint_priority := 1

@export var marker: WireGridMarker
@export var character_switcher: CharacterSwitcher

var is_active := false

func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(ControlsHint.SOURCE_GROUP)
	set_active(is_active)

	if character_switcher:
		character_switcher.switch_started.connect(_on_switch_started)

func _process(_delta):
	if Input.is_action_just_pressed("toggle_wire_puzzle"):
		if is_active:
			set_active(false)
		elif can_open():
			set_active(true)

func _input(event: InputEvent) -> void:
	if is_active and event.is_action_pressed("interface_cancel"):
		get_viewport().set_input_as_handled()
		set_active(false)

func can_open() -> bool:
	if character_switcher == null:
		return true

	return (
		character_switcher.active == CharacterSwitcher.Character.DREADNOUGHT_KILLER
		and not character_switcher.is_transitioning()
	)

func set_active(value: bool):
	is_active = value
	visible = value

	if marker:
		marker.set_process(value)

func is_controls_active() -> bool:
	return is_active and can_process()

func get_control_hints() -> Array:
	return CONTROL_HINTS

func _on_switch_started(_to: CharacterSwitcher.Character) -> void:
	set_active(false)
