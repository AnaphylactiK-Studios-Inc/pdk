extends Node

const BANKS_PATH_SETTING := "Fmod/General/banks_path"
const FALLBACK_BANKS_PATH := "res://assets/audio/pdk-fmod/Build/Desktop"

const MASTER_STRINGS_BANK := "Master.strings.bank"
const MASTER_BANK := "Master.bank"

const UI_EVENTS := {
	&"move": "event:/SFX/UI/sfx_UI_select_nl",
	&"click": "event:/SFX/UI/sfx_UI_click_nl",
	&"back": "event:/SFX/UI/sfx_UI_back_nl",
	&"confirm": "event:/SFX/UI/sfx_UI_confirm_nl",
	&"blocked": "event:/SFX/UI/sfx_UI_blocked_nl",
	&"powerup": "event:/SFX/UI/sfx_UI_powerup_nl",
}

signal banks_loaded
var has_banks := false

var _loader: FmodBankLoader
var _listener: FmodListener3D
var _ui_ok: Dictionary = {}


func _ready() -> void:
	var paths := _collect_bank_paths()
	if paths.is_empty():
		push_warning("AudioManager: no banks found under %s, running silent." % _banks_root())
	else:
		_loader = FmodBankLoader.new()
		_loader.name = "BankLoader"
		_loader.bank_paths = paths
		add_child(_loader)

	var loaded: int = FmodServer.get_all_banks().size()
	if loaded < paths.size():
		push_warning(
			"AudioManager: only %d of %d banks registered with FMOD." % [loaded, paths.size()]
		)

	has_banks = loaded > 0
	_validate_ui_events()
	_setup_listener()

	banks_loaded.emit()
	SettingsManager.bind_audio()


## FMOD needs one listener to pan and attenuate 3D events against. Scenes put
## their camera in different places — the test scene's is static, the circuitry
## scene's rides the player — so rather than making every scene remember to add
## a listener node, this one follows whichever camera is currently active.
func _setup_listener() -> void:
	if not has_banks:
		return
	_listener = FmodListener3D.new()
	_listener.name = "Listener"
	add_child(_listener)


func _process(_delta: float) -> void:
	if _listener == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	# The listener is parented to this autoload, not to the camera, so its
	# global transform is just whatever we assign here.
	_listener.global_transform = camera.global_transform


func _banks_root() -> String:
	var root := String(ProjectSettings.get_setting(BANKS_PATH_SETTING, FALLBACK_BANKS_PATH))
	if root.is_empty():
		root = FALLBACK_BANKS_PATH
	return root.trim_suffix("/")


func _collect_bank_paths() -> Array:
	var root := _banks_root()
	var paths: Array = []

	for required in [MASTER_STRINGS_BANK, MASTER_BANK]:
		var path := "%s/%s" % [root, required]
		if not FileAccess.file_exists(path):
			push_error("AudioManager: %s is missing. Build the FMOD project." % path)
			return []
		paths.append(path)

	var dir := DirAccess.open(root)
	if dir == null:
		return paths

	var names: Array[String] = []
	for file_name in dir.get_files():
		# Exported builds see the .bank files as imported resources.
		file_name = file_name.trim_suffix(".remap").trim_suffix(".import")
		if not file_name.ends_with(".bank"):
			continue
		if file_name == MASTER_STRINGS_BANK or file_name == MASTER_BANK:
			continue
		if not names.has(file_name):
			names.append(file_name)

	names.sort()
	for file_name in names:
		paths.append("%s/%s" % [root, file_name])

	return paths


## Checking once here keeps play_ui() from pushing a warning per keypress if an
## event gets renamed in Studio.
func _validate_ui_events() -> void:
	_ui_ok.clear()
	if not has_banks:
		return
	for kind in UI_EVENTS:
		var path: String = UI_EVENTS[kind]
		if FmodServer.check_event_path(path):
			_ui_ok[kind] = true
		else:
			push_warning("AudioManager: UI event not found, '%s' will be silent: %s" % [kind, path])


# --- Playback ---

## Fires one of UI_EVENTS by role.
func play_ui(kind: StringName) -> void:
	if not _ui_ok.get(kind, false):
		return
	FmodServer.play_one_shot(UI_EVENTS[kind])


## One-shot for anything outside the menus.
func play_one_shot(event_path: String) -> void:
	if not has_banks or event_path.is_empty():
		return
	if not FmodServer.check_event_path(event_path):
		push_warning("AudioManager: event not found: %s" % event_path)
		return
	FmodServer.play_one_shot(event_path)


## One-shot positioned at (and following) a node, for world sounds.
func play_one_shot_attached(event_path: String, node: Node) -> void:
	if not has_banks or event_path.is_empty() or node == null:
		return
	if not FmodServer.check_event_path(event_path):
		push_warning("AudioManager: event not found: %s" % event_path)
		return
	FmodServer.play_one_shot_attached(event_path, node)
