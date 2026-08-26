extends Triggerable
class_name Platform

@export var platform: Node3D
@export var move_height: float = 1.0
@export var duration: float = 1.0

var start_pos: Vector3

func _ready() -> void:
	super._ready()
	start_pos = platform.position
	
	state_changed.connect(_on_state_changed)
	_on_state_changed(is_on)
	
func _on_state_changed(value: bool) -> void:
	if value:
		_lift_platform()
	else:
		_lower_platform()

func _lift_platform() -> void:
	var top_position := start_pos + Vector3.UP * move_height
	
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(
		platform, "position", top_position, duration
	)
	
func _lower_platform() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(
		platform, "position", start_pos, duration
	)
	
