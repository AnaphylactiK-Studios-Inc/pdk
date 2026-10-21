extends CanvasLayer
class_name WirePuzzle

@export var marker: WireGridMarker
@export var character_switcher: CharacterSwitcher

var is_active := false

func _ready() -> void:
	set_active(is_active)

	if character_switcher:
		character_switcher.switch_started.connect(_on_switch_started)

func _process(_delta):
	if Input.is_action_just_pressed("toggle_wire_puzzle"):
		if is_active:
			set_active(false)
		elif can_open():
			set_active(true)
	elif is_active and Input.is_action_just_pressed("interface_cancel"):
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

func _on_switch_started(_to: CharacterSwitcher.Character) -> void:
	set_active(false)
