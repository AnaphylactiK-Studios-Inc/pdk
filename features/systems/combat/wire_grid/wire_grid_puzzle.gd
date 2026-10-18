extends Node2D
class_name WirePuzzle

@export var marker: WireGridMarker

var is_active := true

func _ready():
	set_active(is_active)

func _process(_delta):
	if Input.is_action_just_pressed("toggle_wire_puzzle"):
		set_active(not is_active)

func set_active(value: bool):
	is_active = value
	visible = value

	if marker:
		marker.set_process(value)
