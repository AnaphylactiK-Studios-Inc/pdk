extends Node

const SAVE_PATH := "user://settings.cfg"

const SAVE_DEBOUNCE := 0.4

enum WindowMode { WINDOWED, BORDERLESS, FULLSCREEN }

## Each remappable action keeps at most one binding per family.
enum BindFamily { KBM, JOY }

enum ControllerStyle { AUTO, XBOX, PLAYSTATION, GENERIC }

const CONTROLLER_STYLE_NAMES := {
	ControllerStyle.AUTO: "Auto",
	ControllerStyle.XBOX: "Xbox",
	ControllerStyle.PLAYSTATION: "PlayStation",
	ControllerStyle.GENERIC: "Generic",
}

const XBOX_BUTTON_NAMES := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_BACK: "View",
	JOY_BUTTON_START: "Menu",
	JOY_BUTTON_DPAD_UP: "D-Pad Up",
	JOY_BUTTON_DPAD_DOWN: "D-Pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-Pad Left",
	JOY_BUTTON_DPAD_RIGHT: "D-Pad Right",
	JOY_BUTTON_GUIDE: "Guide",
}

const PLAYSTATION_BUTTON_NAMES := {
	JOY_BUTTON_A: "Cross",
	JOY_BUTTON_B: "Circle",
	JOY_BUTTON_X: "Square",
	JOY_BUTTON_Y: "Triangle",
	JOY_BUTTON_LEFT_SHOULDER: "L1",
	JOY_BUTTON_RIGHT_SHOULDER: "R1",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_BACK: "Share",
	JOY_BUTTON_START: "Options",
	JOY_BUTTON_DPAD_UP: "D-Pad Up",
	JOY_BUTTON_DPAD_DOWN: "D-Pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-Pad Left",
	JOY_BUTTON_DPAD_RIGHT: "D-Pad Right",
	JOY_BUTTON_GUIDE: "PS",
}

const AXIS_NAMES := {
	JOY_AXIS_LEFT_X: "Left Stick X",
	JOY_AXIS_LEFT_Y: "Left Stick Y",
	JOY_AXIS_RIGHT_X: "Right Stick X",
	JOY_AXIS_RIGHT_Y: "Right Stick Y",
	JOY_AXIS_TRIGGER_LEFT: "Left Trigger",
	JOY_AXIS_TRIGGER_RIGHT: "Right Trigger",
}

const VCA_PATHS := {
	"master": "vca:/Master",
	"music": "vca:/Music",
	"sfx": "vca:/SFX",
}

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

## Key = the action name in Project Settings > Input Map.
## Value = the label shown in the controls screen.
const REMAPPABLE_ACTIONS := {
	"move_forward": "Move Forward",
	"move_back": "Move Back",
	"move_left": "Move Left",
	"move_right": "Move Right",
	"jump": "Jump",
}

const DEFAULT_MOUSE_SENSITIVITY := 0.5
const DEFAULT_STICK_SENSITIVITY_X := 0.5
const DEFAULT_STICK_SENSITIVITY_Y := 0.5

const PREVIEW_EVENTS := {
	"master": "event:/UI/SliderPreview",
	"music": "",  # music is already audible; previewing over it is noise
	"sfx": "event:/UI/SliderPreview",
}

signal settings_changed
signal audio_ready
signal keybinds_changed
signal controller_style_changed

var volumes := {"master": 1.0, "music": 1.0, "sfx": 1.0}
var window_mode: int = WindowMode.WINDOWED
var resolution := Vector2i(1920, 1080)
var vsync := true

var mouse_sensitivity: float = DEFAULT_MOUSE_SENSITIVITY
var stick_sensitivity_x: float = DEFAULT_STICK_SENSITIVITY_X
var stick_sensitivity_y: float = DEFAULT_STICK_SENSITIVITY_Y
var controller_style_override: int = ControllerStyle.AUTO

var _vcas: Dictionary = {}
var _preview_ok: Dictionary = {}
var _audio_ready := false
var _save_timer: Timer
var _window_apply_token := 0
var _default_binds: Dictionary = {}
var _detected_controller_style: int = ControllerStyle.GENERIC


func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE
	_save_timer.timeout.connect(save_settings)
	add_child(_save_timer)

	_capture_default_binds()
	load_settings()
	_apply_window()
	_apply_vsync()

	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_detect_controller_style()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _save_timer and not _save_timer.is_stopped():
			_save_timer.stop()
			save_settings()


## Called by AudioManager once banks have finished loading.
func bind_audio() -> void:
	if _audio_ready:
		return

	for key in VCA_PATHS:
		var vca: FmodVCA = FmodServer.get_vca(VCA_PATHS[key])
		if vca == null:
			push_warning("FMOD VCA not found: %s" % VCA_PATHS[key])
			continue
		_vcas[key] = vca

	if _vcas.is_empty():
		print_verbose("SettingsManager: no FMOD VCAs resolved, audio not bound.")
		return

	for key in PREVIEW_EVENTS:
		var path: String = PREVIEW_EVENTS[key]
		if path.is_empty():
			continue
		if FmodServer.get_event(path) == null:
			push_warning("FMOD preview event not found, preview disabled: %s" % path)
			continue
		_preview_ok[key] = true

	_audio_ready = true
	_apply_all_volumes()
	audio_ready.emit()


# --- Public setters ---

func set_volume(key: String, value: float) -> void:
	if not volumes.has(key):
		push_error("Unknown volume key: %s" % key)
		return

	volumes[key] = clampf(value, 0.0, 1.0)
	_apply_volume(key)
	_request_save()
	settings_changed.emit()


## Call from the UI when a volume slider is released.
func preview_volume(key: String) -> void:
	if not _audio_ready:
		return
	if not _preview_ok.get(key, false):
		return
	FmodServer.play_one_shot(PREVIEW_EVENTS[key])


func set_window_mode(mode: int) -> void:
	window_mode = mode
	_apply_window()
	_request_save()
	settings_changed.emit()


func set_resolution(size: Vector2i) -> void:
	resolution = size
	_apply_window()
	_request_save()
	settings_changed.emit()


func set_vsync(enabled: bool) -> void:
	vsync = enabled
	_apply_vsync()
	_request_save()
	settings_changed.emit()


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.0, 1.0)
	_request_save()
	settings_changed.emit()


func set_stick_sensitivity_x(value: float) -> void:
	stick_sensitivity_x = clampf(value, 0.0, 1.0)
	_request_save()
	settings_changed.emit()


func set_stick_sensitivity_y(value: float) -> void:
	stick_sensitivity_y = clampf(value, 0.0, 1.0)
	_request_save()
	settings_changed.emit()


## Pass ControllerStyle.AUTO to go back to auto-detection.
func set_controller_style(style: int) -> void:
	controller_style_override = style
	_request_save()
	settings_changed.emit()
	controller_style_changed.emit()


func get_effective_controller_style() -> int:
	if controller_style_override != ControllerStyle.AUTO:
		return controller_style_override
	return _detected_controller_style


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_detect_controller_style()


func _detect_controller_style() -> void:
	var previous := _detected_controller_style
	var joypads := Input.get_connected_joypads()
	if joypads.is_empty():
		_detected_controller_style = ControllerStyle.GENERIC
	else:
		var joy_name: String = Input.get_joy_name(joypads[0]).to_lower()
		if "xbox" in joy_name or "xinput" in joy_name:
			_detected_controller_style = ControllerStyle.XBOX
		elif "sony" in joy_name or "playstation" in joy_name \
				or "dualshock" in joy_name or "dualsense" in joy_name \
				or "ps3" in joy_name or "ps4" in joy_name or "ps5" in joy_name:
			_detected_controller_style = ControllerStyle.PLAYSTATION
		else:
			_detected_controller_style = ControllerStyle.GENERIC

	if previous != _detected_controller_style and controller_style_override == ControllerStyle.AUTO:
		controller_style_changed.emit()


## Settings menu's Reset — audio/display only, see reset_controls_defaults().
func reset_audio_visual_defaults() -> void:
	volumes = {"master": 1.0, "music": 1.0, "sfx": 1.0}
	window_mode = WindowMode.WINDOWED
	resolution = Vector2i(1920, 1080)
	vsync = true

	_apply_all_volumes()
	_apply_window()
	_apply_vsync()
	save_settings()
	settings_changed.emit()


## Controls menu's Reset — keybinds/sensitivity/style only, see reset_audio_visual_defaults().
func reset_controls_defaults() -> void:
	mouse_sensitivity = DEFAULT_MOUSE_SENSITIVITY
	stick_sensitivity_x = DEFAULT_STICK_SENSITIVITY_X
	stick_sensitivity_y = DEFAULT_STICK_SENSITIVITY_Y
	controller_style_override = ControllerStyle.AUTO

	reset_keybinds()
	save_settings()
	settings_changed.emit()


# --- Input remapping ---

## Restores every remappable action to the bindings the project shipped with.
func reset_keybinds() -> void:
	for action in _default_binds:
		_set_binds(action, (_default_binds[action] as Array).duplicate(true))
	_request_save()
	keybinds_changed.emit()



## Returns -1 for an event kind we don't bind.
func get_event_family(event: InputEvent) -> int:
	if event is InputEventKey or event is InputEventMouseButton:
		return BindFamily.KBM
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return BindFamily.JOY
	return -1


func get_event_for_family(action: String, family: int) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for e in InputMap.action_get_events(action):
		if get_event_family(e) == family:
			return e
	return null


## Human-readable name for a binding, for display on a button.
func describe_event(event: InputEvent) -> String:
	if event == null:
		return "Unbound"
	if event is InputEventKey:
		var code: int = event.physical_keycode
		if code == 0:
			code = event.keycode
		return OS.get_keycode_string(
			DisplayServer.keyboard_get_keycode_from_physical(code)
		)
	if event is InputEventMouseButton:
		return "Mouse %d" % event.button_index
	if event is InputEventJoypadButton:
		return _describe_joy_button(event.button_index)
	if event is InputEventJoypadMotion:
		return _describe_joy_axis(event.axis, event.axis_value)
	return event.as_text()


func _describe_joy_button(button_index: int) -> String:
	match get_effective_controller_style():
		ControllerStyle.XBOX:
			if XBOX_BUTTON_NAMES.has(button_index):
				return XBOX_BUTTON_NAMES[button_index]
		ControllerStyle.PLAYSTATION:
			if PLAYSTATION_BUTTON_NAMES.has(button_index):
				return PLAYSTATION_BUTTON_NAMES[button_index]
	return "Pad %d" % button_index


func _describe_joy_axis(axis: int, axis_value: float) -> String:
	if axis == JOY_AXIS_TRIGGER_LEFT or axis == JOY_AXIS_TRIGGER_RIGHT:
		return AXIS_NAMES.get(axis, "Axis %d" % axis)
	var base: String = AXIS_NAMES.get(axis, "Axis %d" % axis)
	return "%s %s" % [base, "+" if axis_value > 0.0 else "-"]


## True if the event is a kind we're willing to store.
func is_bindable(event: InputEvent) -> bool:
	return event is InputEventKey \
		or event is InputEventMouseButton \
		or event is InputEventJoypadButton \
		or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5)


## Rebinds only the family the event belongs to, leaving the other family's
## binding on this action untouched.
func rebind_action(action: String, event: InputEvent) -> void:
	if not REMAPPABLE_ACTIONS.has(action):
		push_error("Action is not remappable: %s" % action)
		return
	if not is_bindable(event):
		return

	var family := get_event_family(event)
	var incoming := _event_to_dict(event)

	for other in REMAPPABLE_ACTIONS:
		if other == action:
			continue
		var kept: Array = []
		var changed := false
		for e in InputMap.action_get_events(other):
			if get_event_family(e) == family and _event_to_dict(e) == incoming:
				changed = true
				continue
			kept.append(_event_to_dict(e))
		if changed:
			_set_binds(other, kept)

	var kept_self: Array = []
	for e in InputMap.action_get_events(action):
		if get_event_family(e) != family:
			kept_self.append(_event_to_dict(e))
	kept_self.append(incoming)
	_set_binds(action, kept_self)

	_request_save()
	keybinds_changed.emit()


func clear_action(action: String, family: int) -> void:
	if not REMAPPABLE_ACTIONS.has(action):
		return
	var kept: Array = []
	for e in InputMap.action_get_events(action):
		if get_event_family(e) != family:
			kept.append(_event_to_dict(e))
	_set_binds(action, kept)
	_request_save()
	keybinds_changed.emit()


func _capture_default_binds() -> void:
	for action in REMAPPABLE_ACTIONS:
		if not InputMap.has_action(action):
			push_warning("Remappable action missing from Input Map: %s" % action)
			continue
		var dicts: Array = []
		for e in InputMap.action_get_events(action):
			var d := _event_to_dict(e)
			if not d.is_empty():
				dicts.append(d)
		_default_binds[action] = dicts


func _set_binds(action: String, dicts: Array) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	for d in dicts:
		var e := _dict_to_event(d)
		if e != null:
			InputMap.action_add_event(action, e)


func _event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var code: int = event.physical_keycode
		if code == 0:
			code = event.keycode
		return {"type": "key", "code": int(code)}
	if event is InputEventMouseButton:
		return {"type": "mouse", "index": int(event.button_index)}
	if event is InputEventJoypadButton:
		return {"type": "joy_button", "index": int(event.button_index)}
	if event is InputEventJoypadMotion:
		return {
			"type": "joy_axis",
			"axis": int(event.axis),
			"value": signf(event.axis_value),
		}
	return {}


func _dict_to_event(d: Dictionary) -> InputEvent:
	match String(d.get("type", "")):
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = int(d.get("code", 0)) as Key
			return k
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = int(d.get("index", 0)) as MouseButton
			return m
		"joy_button":
			var b := InputEventJoypadButton.new()
			b.button_index = int(d.get("index", 0)) as JoyButton
			return b
		"joy_axis":
			var a := InputEventJoypadMotion.new()
			a.axis = int(d.get("axis", 0)) as JoyAxis
			a.axis_value = float(d.get("value", 1.0))
			return a
	return null


# --- Applying ---

func _apply_all_volumes() -> void:
	for key in volumes:
		_apply_volume(key)


func _apply_volume(key: String) -> void:
	if not _vcas.has(key):
		return
	_vcas[key].set_volume(pow(volumes[key], 2.0))


func _apply_window() -> void:
	_window_apply_token += 1
	var token := _window_apply_token

	match window_mode:
		WindowMode.FULLSCREEN:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			await get_tree().process_frame
			if token != _window_apply_token:
				return
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

		WindowMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			await get_tree().process_frame
			if token != _window_apply_token:
				return
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var screen := DisplayServer.window_get_current_screen()
			DisplayServer.window_set_size(DisplayServer.screen_get_size(screen))
			DisplayServer.window_set_position(DisplayServer.screen_get_position(screen))

		WindowMode.WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			await get_tree().process_frame
			if token != _window_apply_token:
				return
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			await get_tree().process_frame
			if token != _window_apply_token:
				return
			DisplayServer.window_set_size(resolution)
			_center_window()


func _center_window() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var size := DisplayServer.window_get_size()
	@warning_ignore("integer_division")  # Window positions are whole pixels anyway.
	DisplayServer.window_set_position(
		usable.position + (usable.size - size) / 2
	)


func _apply_vsync() -> void:
	var mode := DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)


# --- Persistence ---

func _request_save() -> void:
	if _save_timer:
		_save_timer.start()
	else:
		save_settings()


func save_settings() -> void:
	var config := ConfigFile.new()
	for key in volumes:
		config.set_value("audio", key, volumes[key])

	config.set_value("display", "window_mode", int(window_mode))
	config.set_value("display", "resolution_x", resolution.x)
	config.set_value("display", "resolution_y", resolution.y)
	config.set_value("display", "vsync", vsync)

	config.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("input", "stick_sensitivity_x", stick_sensitivity_x)
	config.set_value("input", "stick_sensitivity_y", stick_sensitivity_y)
	config.set_value("input", "controller_style", int(controller_style_override))

	for action in REMAPPABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var dicts: Array = []
		for e in InputMap.action_get_events(action):
			var d := _event_to_dict(e)
			if not d.is_empty():
				dicts.append(d)
		config.set_value("input", action, dicts)

	var error := config.save(SAVE_PATH)
	if error != OK:
		push_error("Could not save settings: %s" % error_string(error))


func load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		return  # No file yet: keep the defaults above.

	for key in volumes:
		volumes[key] = clampf(float(config.get_value("audio", key, volumes[key])), 0.0, 1.0)

	# Migration: older builds saved a plain fullscreen bool.
	if config.has_section_key("display", "window_mode"):
		window_mode = clampi(
			int(config.get_value("display", "window_mode", window_mode)),
			0, WindowMode.size() - 1
		)
	elif config.has_section_key("display", "fullscreen"):
		window_mode = WindowMode.FULLSCREEN if bool(
			config.get_value("display", "fullscreen", false)
		) else WindowMode.WINDOWED

	resolution = Vector2i(
		int(config.get_value("display", "resolution_x", resolution.x)),
		int(config.get_value("display", "resolution_y", resolution.y)),
	)
	vsync = bool(config.get_value("display", "vsync", vsync))

	mouse_sensitivity = clampf(
		float(config.get_value("input", "mouse_sensitivity", mouse_sensitivity)), 0.0, 1.0
	)

	# Migration: older builds saved a single stick_sensitivity for both axes.
	var legacy_stick: float = float(
		config.get_value("input", "stick_sensitivity", stick_sensitivity_x)
	)
	stick_sensitivity_x = clampf(
		float(config.get_value("input", "stick_sensitivity_x", legacy_stick)), 0.0, 1.0
	)
	stick_sensitivity_y = clampf(
		float(config.get_value("input", "stick_sensitivity_y", legacy_stick)), 0.0, 1.0
	)

	controller_style_override = clampi(
		int(config.get_value("input", "controller_style", controller_style_override)),
		0, ControllerStyle.size() - 1
	)

	for action in REMAPPABLE_ACTIONS:
		if not config.has_section_key("input", action):
			continue
		var dicts: Array = config.get_value("input", action, [])
		_set_binds(action, dicts)
