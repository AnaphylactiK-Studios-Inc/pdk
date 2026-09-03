extends CharacterBody3D

enum Gait { CRAWL, WALK, SPRINT }
enum State { GROUNDED, JUMP_START, AIR, LAND, DASH }

## Emitted when a foot lands. FMOD will hook this for footstep audio.
signal stepped(world_position: Vector3, noise: float)
signal dash_started(direction: Vector3)
signal dash_finished()
signal crawl_changed(crawling: bool)

const LAND_LENGTH := 0.5

@export_group("Speed")
@export var walk_speed := 3.0
@export var sprint_speed := 5.0
@export var crawl_speed := 1.1
## Sprint stays off below this stick deflection, so a gentle tilt still creeps.
@export_range(0.0, 1.0) var sprint_stick_threshold := 0.8

@export_group("Acceleration")
@export var ground_acceleration := 18.0
@export var ground_friction := 22.0
@export var air_acceleration := 7.0
@export var air_friction := 2.0
@export var turn_sharpness := 18.0

@export_group("Jump")
@export var jump_velocity := 4.7
@export var coyote_time := 0.12  # Time after leaving ground that a jump is still allowed
@export var jump_buffer_time := 0.15
## Fraction of upward speed kept when jump is released early. Lower is snappier.
@export_range(0.0, 1.0) var jump_release_damping := 0.55
@export var fall_gravity_multiplier := 1.3
@export var terminal_velocity := 16.0

@export_group("Dash")
@export var dash_speed := 9.0
@export var dash_duration := 0.18
@export var dash_cooldown := 0.55
@export_range(0.0, 1.0) var dash_vertical_damping := 0.0

@export_group("Crawl")
## Collision height while crawling
@export_range(0.2, 1.0) var crawl_height_ratio := 0.5
@export_range(0.0, 1.0) var crawl_dash_scale := 0.4

@export_group("Grounding")
## How far below her origin to look for the floor when planting the model, and
## the furthest the model will ever be dropped.
@export var foot_probe_length := 0.18
## How fast the model settles onto the probed floor height.
@export var foot_plant_sharpness := 20.0
@export var foot_offset := 0.0

@export_group("Steps")
@export var step_length := 0.5
@export_range(0.1, 1.0) var crawl_step_scale := 0.6
@export var crawl_noise := 0.15
@export var walk_noise := 1.0
@export var sprint_noise := 1.8

@onready var model: Node3D = $peanut
@onready var anim: AnimationPlayer = $peanut/AnimationPlayer
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var interaction_area := $InteractionArea
@onready var dash_dust: GPUParticles3D = $DashDust

var state: State = State.GROUNDED
var gait: Gait = Gait.WALK
var crawling := false

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _dash_direction := Vector3.ZERO
var _sprint_input := false
var _sprint_latched := false
var _step_distance := 0.0
var _stand_height := 0.0
var _stand_offset := 0.0
var _capsule: CapsuleShape3D
var _foot_drop := 0.0


func _ready() -> void:
	if anim.has_animation("jump_mid_air"):
		anim.get_animation("jump_mid_air").loop_mode = Animation.LOOP_LINEAR
	if anim.has_animation("jump_start"):
		anim.get_animation("jump_start").loop_mode = Animation.LOOP_NONE
	if anim.has_animation("land"):
		var land := anim.get_animation("land")
		land.loop_mode = Animation.LOOP_NONE
		land.length = LAND_LENGTH
	if anim.has_animation("interact"):
		anim.get_animation("interact").loop_mode = Animation.LOOP_NONE

	interaction_area.interact_started.connect(_on_interact_started)
	interaction_area.rotation.y = model.rotation.y

	# Keeps the character from sliding down slopes when standing still
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50.0)

	# Duplicate the shared sub-resource so crawling doesn't resize every Peanut.
	if collider.shape is CapsuleShape3D:
		_capsule = collider.shape.duplicate()
		collider.shape = _capsule
		_stand_height = _capsule.height
		_stand_offset = collider.position.y


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()

	_tick_timers(delta, on_floor)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var strength := minf(input.length(), 1.0)
	var wish_dir := _camera_relative_direction(input)

	_sprint_input = _read_sprint(strength)
	_update_crawl(on_floor)
	_update_gait(strength)

	if _try_start_dash(wish_dir):
		on_floor = is_on_floor()

	if state == State.DASH:
		_move_dashing(delta)
	else:
		_apply_gravity(delta, on_floor)
		_try_jump()
		_move_walking(delta, wish_dir, strength, on_floor)

	_face_movement(delta, wish_dir)
	_update_state(on_floor, wish_dir)
	_update_animation(wish_dir)

	move_and_slide()

	_plant_feet(delta)
	_update_steps(delta)


## Input direction in world space, relative to where the camera is looking.
func _camera_relative_direction(input_dir: Vector2) -> Vector3:
	if input_dir == Vector2.ZERO:
		return Vector3.ZERO

	var cam := get_viewport().get_camera_3d()
	if cam == null:
		# No active camera: fall back to world-relative movement.
		return Vector3(input_dir.x, 0, input_dir.y).normalized()

	var cam_basis := cam.global_transform.basis

	# basis.z points back toward the camera, so forward input (-1) moves away.
	var forward := cam_basis.z
	forward.y = 0
	forward = forward.normalized()

	var right := cam_basis.x
	right.y = 0
	right = right.normalized()

	return (right * input_dir.x + forward * input_dir.y).normalized()


func _tick_timers(delta: float, on_floor: bool) -> void:
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	if on_floor:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time


# --- Stance and gait ---

func _update_crawl(on_floor: bool) -> void:
	var want_crawl := crawling

	if SettingsManager.crawl_toggle:
		if Input.is_action_just_pressed("crawl"):
			want_crawl = not crawling
	else:
		want_crawl = Input.is_action_pressed("crawl")

	# Sprinting out of a crawl is the natural way to stand back up.
	if want_crawl and _sprint_input:
		want_crawl = false

	# Crawling is a ground stance.
	if not on_floor:
		want_crawl = false

	if want_crawl == crawling:
		return
	if not want_crawl and not _has_headroom():
		return  # Stuck under something: stay down until there is room.

	crawling = want_crawl
	_apply_stance_height()
	crawl_changed.emit(crawling)


func _apply_stance_height() -> void:
	if _capsule == null:
		return
	var height := _stand_height
	if crawling:
		height = maxf(_stand_height * crawl_height_ratio, _capsule.radius * 2.0)
	_capsule.height = height
	# Keep the capsule's feet planted while its top moves.
	collider.position.y = _stand_offset - (_stand_height - height) * 0.5


## True if there is room to stand up where she is right now.
func _has_headroom() -> bool:
	if _capsule == null:
		return true

	var probe := CapsuleShape3D.new()
	probe.radius = _capsule.radius * 0.95  # Slight shrink so walls don't count.
	probe.height = _stand_height

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = probe
	params.transform = Transform3D(
		Basis.IDENTITY, global_position + Vector3.UP * _stand_offset
	)
	params.collision_mask = collision_mask
	params.exclude = [get_rid()]

	return get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


## Hold-to-run, or toggle-to-run if the player picked that in the controls menu.
func _read_sprint(strength: float) -> bool:
	if not SettingsManager.sprint_toggle:
		return Input.is_action_pressed("sprint")

	if Input.is_action_just_pressed("sprint"):
		_sprint_latched = not _sprint_latched
	if strength <= 0.0:
		_sprint_latched = false  # Coming to a stop drops the latch.
	return _sprint_latched


func _update_gait(strength: float) -> void:
	if crawling:
		gait = Gait.CRAWL
	elif _sprint_input and strength >= sprint_stick_threshold:
		gait = Gait.SPRINT
	else:
		gait = Gait.WALK


func top_speed() -> float:
	match gait:
		Gait.CRAWL:
			return crawl_speed
		Gait.SPRINT:
			return sprint_speed
		_:
			return walk_speed


## How much noise she is currently making, for stealth and AI hearing.
func noise_level() -> float:
	if velocity.length() < 0.05:
		return 0.0
	match gait:
		Gait.CRAWL:
			return crawl_noise
		Gait.SPRINT:
			return sprint_noise
		_:
			return walk_noise


# --- Movement ---

func _apply_gravity(delta: float, on_floor: bool) -> void:
	if on_floor:
		return

	var gravity := get_gravity()
	# A heavier fall than rise keeps the jump arc from feeling floaty.
	if velocity.y < 0.0:
		gravity *= fall_gravity_multiplier
	velocity += gravity * delta
	velocity.y = maxf(velocity.y, -terminal_velocity)


func _try_jump() -> void:
	# Releasing early cuts the jump short, giving one button two heights.
	if not Input.is_action_pressed("jump") and velocity.y > 0.0 and state != State.GROUNDED:
		velocity.y *= jump_release_damping

	if _jump_buffer_timer <= 0.0 or _coyote_timer <= 0.0:
		return

	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	velocity.y = jump_velocity
	state = State.JUMP_START
	_play("jump_start")

	if crawling and _has_headroom():
		crawling = false
		_apply_stance_height()
		crawl_changed.emit(false)


func _move_walking(delta: float, wish_dir: Vector3, strength: float, on_floor: bool) -> void:
	var target := Vector3(wish_dir.x, 0.0, wish_dir.z) * top_speed() * strength
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)

	var accelerating := wish_dir != Vector3.ZERO
	var rate: float
	if on_floor:
		rate = ground_acceleration if accelerating else ground_friction
	else:
		rate = air_acceleration if accelerating else air_friction

	# Framerate-independent exponential approach.
	horizontal = horizontal.lerp(target, 1.0 - exp(-rate * delta))
	if not accelerating and horizontal.length() < 0.05:
		horizontal = Vector3.ZERO

	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _face_movement(delta: float, wish_dir: Vector3) -> void:
	var facing := _dash_direction if state == State.DASH else wish_dir
	if facing == Vector3.ZERO:
		return
	var target_yaw := atan2(facing.x, facing.z)
	model.rotation.y = lerp_angle(
		model.rotation.y, target_yaw, 1.0 - exp(-turn_sharpness * delta)
	)
	interaction_area.rotation.y = model.rotation.y


# --- Dash ---

func _try_start_dash(wish_dir: Vector3) -> bool:
	if not Input.is_action_just_pressed("dash"):
		return false
	if state == State.DASH or _dash_cooldown_timer > 0.0:
		return false

	# Ground-only dash. Coyote time counts, so walking off a lip doesn't eat it.
	if not is_on_floor() and _coyote_timer <= 0.0:
		return false

	# Dash where she is pointed if there is no input to read.
	_dash_direction = wish_dir
	if _dash_direction == Vector3.ZERO:
		_dash_direction = Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))

	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown + dash_duration
	state = State.DASH
	velocity.y *= dash_vertical_damping
	_play("dash", "run")
	_start_dash_dust()
	dash_started.emit(_dash_direction)
	return true


## The emitter sprays along its own +Z, so aim that opposite the dash and the
## dust trails off her heels. Restarting clears the last dash's puff, which
## otherwise lingers into a quick second dash.
func _start_dash_dust() -> void:
	dash_dust.rotation.y = atan2(-_dash_direction.x, -_dash_direction.z)
	dash_dust.restart()
	dash_dust.emitting = true


func _move_dashing(delta: float) -> void:
	_dash_timer -= delta

	var speed := dash_speed
	if crawling:
		speed *= crawl_dash_scale
	velocity.x = _dash_direction.x * speed
	velocity.z = _dash_direction.z * speed

	if _dash_timer > 0.0:
		return

	# Carry the dash's momentum into normal movement so a dash into a run flows.
	var carry := top_speed()
	velocity.x = _dash_direction.x * carry
	velocity.z = _dash_direction.z * carry
	state = State.GROUNDED if is_on_floor() else State.AIR
	dash_dust.emitting = false
	dash_finished.emit()


# --- State and animation ---

func _update_state(on_floor: bool, wish_dir: Vector3) -> void:
	if state == State.DASH:
		return

	if not on_floor and state != State.JUMP_START and state != State.AIR:
		state = State.AIR
		_play("jump_mid_air")
	elif on_floor and velocity.y <= 0.0 and (state == State.JUMP_START or state == State.AIR):
		if wish_dir:
			state = State.GROUNDED
		else:
			state = State.LAND
			_play("land")
	elif state == State.JUMP_START and _clip_finished():
		state = State.AIR
		_play("jump_mid_air")
	elif state == State.LAND and (wish_dir or _clip_finished()):
		state = State.GROUNDED


func _clip_finished() -> bool:
	return anim.current_animation_position >= anim.current_animation_length


func _update_animation(wish_dir: Vector3) -> void:
	if state != State.GROUNDED:
		return

	# Let the interact clip finish instead of being cut off by idle/run.
	if anim.current_animation == "interact" and not _clip_finished():
		return

	var speed := Vector2(velocity.x, velocity.z).length()
	var moving := wish_dir != Vector3.ZERO or speed > 0.1

	if not moving:
		anim.speed_scale = 1.0
		_play("idle")
		return

	if crawling:
		_play("crawl", "run")
	else:
		_play("run")

	# No separate walk/sprint clips yet, so scale the run cycle by actual speed.
	anim.speed_scale = clampf(speed / maxf(walk_speed, 0.01), 0.5, 1.9)


## Plays `clip`, or `fallback` if `clip` hasn't been authored yet.
func _play(clip: String, fallback: String = "") -> void:
	var want := clip
	if not anim.has_animation(want):
		if fallback.is_empty() or not anim.has_animation(fallback):
			return
		want = fallback
	if anim.current_animation != want:
		anim.play(want)


func _on_interact_started(_trigger: ManualTrigger) -> void:
	anim.speed_scale = 1.0
	_play("interact")


## A capsule meets a slope tangentially, so its lowest point never reaches the
## surface the player can see: on an incline the body rides
## radius * (1 / cos(angle) - 1) above the ground directly beneath it, and that
## gap is what reads as Peanut hovering. Probing straight down and dropping the
## model by the difference plants her feet without disturbing the collision the
## rest of the movement code is built on.
func _plant_feet(delta: float) -> void:
	var target := 0.0

	if is_on_floor():
		var from := global_position + Vector3.UP * 0.1
		var params := PhysicsRayQueryParameters3D.create(
			from, from + Vector3.DOWN * (0.1 + foot_probe_length)
		)
		params.collision_mask = collision_mask
		params.exclude = [get_rid()]

		var hit := get_world_3d().direct_space_state.intersect_ray(params)
		if not hit.is_empty():
			# Only ever lower her: raising the model would push her into ledges.
			target = clampf(hit.position.y - global_position.y, -foot_probe_length, 0.0)

	_foot_drop = lerpf(_foot_drop, target, 1.0 - exp(-foot_plant_sharpness * delta))
	model.position.y = _foot_drop + foot_offset


# --- Steps ---

func _update_steps(delta: float) -> void:
	if state != State.GROUNDED or not is_on_floor():
		_step_distance = 0.0
		return

	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.1:
		_step_distance = 0.0
		return

	_step_distance += speed * delta

	# Crawling covers less ground per step.
	var stride := step_length * (crawl_step_scale if crawling else 1.0)
	if _step_distance < stride:
		return

	_step_distance -= stride

	stepped.emit(global_position, noise_level())
