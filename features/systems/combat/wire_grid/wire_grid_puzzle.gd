extends CanvasLayer
class_name WirePuzzle

@export var marker: WireGridMarker
@export var character_switcher: CharacterSwitcher

var is_active := false

func _ready() -> void:
	set_active(is_active)
	
func _process(_delta):
	if not Input.is_action_just_pressed("toggle_wire_puzzle"):
		return

	if character_switcher and character_switcher.active != CharacterSwitcher.Character.DREADNOUGHT_KILLER:
		return

	set_active(not is_active)

func set_active(value: bool):
	is_active = value
	visible = value

	if marker:
		marker.set_process(value)
