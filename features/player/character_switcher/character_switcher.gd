class_name CharacterSwitcher
extends Node

## Hands control between Peanut and Dreadnought Killer on "switch_character".
##
## Only one character has control at a time. Dreadnought Killer is set to
## PROCESS_MODE_DISABLED while idle; Peanut keeps simulating and animating with
## her input cut, so she stays alive in the world. While the view travels,
## neither has control, and a throwaway camera flies from the outgoing view to
## the incoming one, so both rigs stay untouched.
##
## A press that comes while the active character can't let go (Peanut in the
## air or dashing, DK mid-step) is held and carried out once it can.

signal switch_started(to: Character)
signal switch_finished(to: Character)

enum Character { PEANUT, DREADNOUGHT_KILLER }

@export_group("Wiring")
@export var peanut: Node3D
@export var peanut_camera: PeanutCamera
@export var dreadnought_killer: Node3D
@export var dreadnought_killer_camera: Camera3D

@export_group("Transition")
@export var starting_character := Character.PEANUT
## The pan takes longer the further the characters are apart
@export var min_duration := 0.6
@export var max_duration := 1.6
@export var travel_speed := 40.0
## How far the camera rises mid-pan
@export_range(0.0, 1.0) var arc_ratio := 0.15
@export var max_arc_height := 12.0

var active := Character.PEANUT
var _transitioning := false
var _switch_requested := false
var _transition_camera: Camera3D


func _ready() -> void:
	if peanut == null or peanut_camera == null \
			or dreadnought_killer == null or dreadnought_killer_camera == null:
		push_error("CharacterSwitcher: a character or camera is unassigned; switching disabled.")
		set_process_unhandled_input(false)
		set_physics_process(false)
		return

	process_physics_priority = -1

	_transition_camera = Camera3D.new()
	_transition_camera.name = "TransitionCamera"
	add_child(_transition_camera)

	active = starting_character
	_give_control(active)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_character") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if _transitioning:
			return
		_switch_requested = not _switch_requested


func _physics_process(_delta: float) -> void:
	if _switch_requested and can_switch():
		_switch_requested = false
		switch_character()


func is_transitioning() -> bool:
	return _transitioning


func is_switch_pending() -> bool:
	return _switch_requested


func switch_character() -> void:
	if not can_switch():
		return
	var next := Character.DREADNOUGHT_KILLER if active == Character.PEANUT else Character.PEANUT
	_switch_to(next)


func can_switch() -> bool:
	if _transitioning or _transition_camera == null:
		return false
	if active == Character.PEANUT:
		return peanut.can_hand_off()
	return not dreadnought_killer.is_busy()


func _switch_to(next: Character) -> void:
	_transitioning = true
	switch_started.emit(next)

	var from_camera := _camera_for(active)
	var to_camera := _camera_for(next)

	_set_enabled(active, false)

	var from := from_camera.global_transform
	var to := to_camera.global_transform
	var distance := from.origin.distance_to(to.origin)
	var arc := minf(distance * arc_ratio, max_arc_height)
	var duration := clampf(distance / maxf(travel_speed, 0.01), min_duration, max_duration)

	_transition_camera.fov = from_camera.fov
	_transition_camera.near = minf(from_camera.near, to_camera.near)
	_transition_camera.far = maxf(from_camera.far, to_camera.far)
	_transition_camera.global_transform = from
	_transition_camera.make_current()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		_step_transition.bind(from, to, arc, from_camera.fov, to_camera.fov),
		0.0, 1.0, duration
	)

	await tween.finished

	if not is_inside_tree():
		return

	active = next
	_give_control(next)
	_transitioning = false
	switch_finished.emit(next)


func _step_transition(
	t: float, from: Transform3D, to: Transform3D, arc: float, from_fov: float, to_fov: float
) -> void:
	var xform := from.interpolate_with(to, t)
	xform.origin.y += sin(t * PI) * arc
	_transition_camera.global_transform = xform
	_transition_camera.fov = lerpf(from_fov, to_fov, t)


func _give_control(character: Character) -> void:
	_set_enabled(Character.PEANUT, character == Character.PEANUT)
	_set_enabled(Character.DREADNOUGHT_KILLER, character == Character.DREADNOUGHT_KILLER)
	_camera_for(character).make_current()


func _set_enabled(character: Character, enabled: bool) -> void:
	var mode := Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	match character:
		Character.PEANUT:
			peanut.set_has_control(enabled)
			peanut_camera.process_mode = mode
		Character.DREADNOUGHT_KILLER:
			dreadnought_killer.process_mode = mode


func _camera_for(character: Character) -> Camera3D:
	if character == Character.PEANUT:
		return peanut_camera.camera
	return dreadnought_killer_camera
