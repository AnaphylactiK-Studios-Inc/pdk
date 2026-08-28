extends Node

const SAVE_PATH := "user://settings.cfg"

const SAVE_DEBOUNCE := 0.4

enum WindowMode { WINDOWED, BORDERLESS, FULLSCREEN }

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
	"move_left": "Move Left",
	"move_right": "Move Right",
	"move_up": "Move Up",
	"move_down": "Move Down",
	"jump": "Jump",
}

const PREVIEW_EVENTS := {
	"master": "event:/UI/SliderPreview",
	"music": "",  # music is already audible; previewing over it is noise
	"sfx": "event:/UI/SliderPreview",
}

signal settings_changed
signal audio_ready
signal keybinds_changed

var volumes := {"master": 1.0, "music": 1.0, "sfx": 1.0}
var window_mode: int = WindowMode.WINDOWED
var resolution := Vector2i(1920, 1080)
var vsync := true

var _vcas: Dictionary = {}
var _preview_ok: Dictionary = {}
var _audio_ready := false
var _save_timer: Timer
var _window_apply_token := 0
var _default_binds: Dictionary = {}


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


func reset_to_defaults() -> void:
	volumes = {"master": 1.0, "music": 1.0, "sfx": 1.0}
	window_mode = WindowMode.WINDOWED
	resolution = Vector2i(1920, 1080)
	vsync = true

	reset_keybinds()

	_apply_all_volumes()
	_apply_window()
	_apply_vsync()
	save_settings()
	settings_changed.emit()
	keybinds_changed.emit()


# --- Input remapping ---

## Restores every remappable action to the bindings the project shipped with.
func reset_keybinds() -> void:
	for action in _default_binds:
		_set_binds(action, (_default_binds[action] as Array).duplicate(true))
	_request_save()
	keybinds_changed.emit()



## Returns the primary event bound to an action, or null if it has none.
func get_primary_event(action: String) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	var events := InputMap.action_get_events(action)
	return events[0] if not events.is_empty() else null


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
		return "Pad %d" % event.button_index
	if event is InputEventJoypadMotion:
		return "Axis %d%s" % [event.axis, "+" if event.axis_value > 0.0 else "-"]
	return event.as_text()


## True if the event is a kind we're willing to store.
func is_bindable(event: InputEvent) -> bool:
	return event is InputEventKey \
		or event is InputEventMouseButton \
		or event is InputEventJoypadButton \
		or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5)


## Rebinds an action to a single event, clearing that event off any other
## remappable action so two actions can't share a key.
func rebind_action(action: String, event: InputEvent) -> void:
	if not REMAPPABLE_ACTIONS.has(action):
		push_error("Action is not remappable: %s" % action)
		return
	if not is_bindable(event):
		return

	var incoming := _event_to_dict(event)
	for other in REMAPPABLE_ACTIONS:
		if other == action:
			continue
		var kept: Array = []
		for e in InputMap.action_get_events(other):
			if _event_to_dict(e) != incoming:
				kept.append(_event_to_dict(e))
		if kept.size() != InputMap.action_get_events(other).size():
			_set_binds(other, kept)

	_set_binds(action, [incoming])
	_request_save()
	keybinds_changed.emit()


func clear_action(action: String) -> void:
	if not REMAPPABLE_ACTIONS.has(action):
		return
	_set_binds(action, [])
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
	# Squaring maps the linear slider onto something closer to perceived
	# loudness, so the useful range isn't crammed into the top 20%.
	_vcas[key].set_volume(pow(volumes[key], 2.0))


## Leaving fullscreen is not instant. The OS restores the window over the next
## frame or two, and size/position/border changes issued in the same frame as
## the mode change are applied to the window that is still on its way out, so
## they get overwritten. Each step therefore waits a frame.
##
## _window_apply_token cancels an in-flight sequence if the player picks another
## mode mid-transition, otherwise two coroutines fight over the window.
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
			# The border has to come back before the size is set, or the size is
			# applied to a still-borderless window and the title bar pushes the
			# content down when it finally appears.
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

	for action in REMAPPABLE_ACTIONS:
		if not config.has_section_key("input", action):
			continue
		var dicts: Array = config.get_value("input", action, [])
		_set_binds(action, dicts)
