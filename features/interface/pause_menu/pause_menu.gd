extends CanvasLayer

## In-game pause menu. It's an autoload so every level gets it without adding a
## node to each scene; menus that shouldn't be pausable put their root scene in
## BLOCKED_GROUP.

const BLOCKED_GROUP := &"pause_blocked"
const CURRENT_LEVEL_SUFFIX := "  (current)"

@export var settings_scene: PackedScene

@onready var menu_root: Control = %MenuRoot
@onready var main_page: Control = %MainPage
@onready var level_page: Control = %LevelPage
@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var levels_button: Button = %LevelsButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var level_list: VBoxContainer = %LevelList
@onready var levels_back_button: Button = %LevelsBackButton

var _settings_instance: Node = null
var _mouse_mode_before_pause := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	visible = false

	resume_button.pressed.connect(resume)
	settings_button.pressed.connect(_on_settings_pressed)
	levels_button.pressed.connect(_show_level_page)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	levels_back_button.pressed.connect(_on_levels_back_pressed)

	# These play the back sound from their own handlers.
	resume_button.set_meta(MenuAudio.ROLE_META, &"none")
	levels_back_button.set_meta(MenuAudio.ROLE_META, &"none")
	MenuAudio.wire(self)


## Opening runs in _input so the camera never sees the Escape and drops the
## mouse on its own.
func _input(event: InputEvent) -> void:
	if visible or not event.is_action_pressed("pause"):
		return
	if not can_pause():
		return
	get_viewport().set_input_as_handled()
	pause()


## Closing waits for _unhandled_input so an open submenu gets the cancel first.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or is_instance_valid(_settings_instance):
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if level_page.visible:
			_on_levels_back_pressed()
		else:
			resume()
	elif event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		resume()


func can_pause() -> bool:
	var scene := get_tree().current_scene
	return scene != null and not scene.is_in_group(BLOCKED_GROUP) and not get_tree().paused


func pause() -> void:
	_mouse_mode_before_pause = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	visible = true
	MenuAudio.confirm()
	_show_main_page(resume_button)


func resume() -> void:
	if not visible:
		return
	_close()
	Input.mouse_mode = _mouse_mode_before_pause
	MenuAudio.back()


func _close() -> void:
	_close_settings()
	visible = false
	get_tree().paused = false


func _change_scene(path: String) -> void:
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		MenuAudio.blocked()
		push_error("Could not load scene %s: %s" % [path, error_string(error)])
		return
	_close()
	# The next scene decides for itself whether it wants the mouse captured.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- Pages ---

func _show_main_page(focus: Control) -> void:
	level_page.visible = false
	main_page.visible = true
	MenuAudio.focus_silently(focus)


func _show_level_page() -> void:
	_build_level_list()
	main_page.visible = false
	level_page.visible = true


func _build_level_list() -> void:
	for child in level_list.get_children():
		level_list.remove_child(child)
		child.queue_free()

	var current_path := get_tree().current_scene.scene_file_path
	var focus: Button = null
	for level: Dictionary in LevelCatalog.LEVELS:
		var button := Button.new()
		button.text = level["name"]
		if level["path"] == current_path:
			button.text += CURRENT_LEVEL_SUFFIX
			focus = button
		button.pressed.connect(_change_scene.bind(level["path"]))
		level_list.add_child(button)

	MenuAudio.wire(level_list)
	if focus == null and level_list.get_child_count() > 0:
		focus = level_list.get_child(0)
	MenuAudio.focus_silently(focus if focus != null else levels_back_button)


# --- Handlers ---

func _on_levels_back_pressed() -> void:
	MenuAudio.back()
	_show_main_page(levels_button)


func _on_main_menu_pressed() -> void:
	_change_scene(ProjectSettings.get_setting("application/run/main_scene"))


func _on_settings_pressed() -> void:
	if settings_scene == null:
		MenuAudio.blocked()
		push_warning("Pause menu has no settings scene assigned.")
		return
	if is_instance_valid(_settings_instance):
		return

	var settings := settings_scene.instantiate()
	settings.closed.connect(_on_settings_closed)
	_settings_instance = settings
	add_child(settings)
	# Hidden rather than just unfocusable, so the two panels don't stack.
	menu_root.visible = false


func _on_settings_closed() -> void:
	_close_settings()
	# The settings panel already played its own close sound.
	MenuAudio.focus_silently(settings_button)


func _close_settings() -> void:
	if is_instance_valid(_settings_instance):
		_settings_instance.queue_free()
	_settings_instance = null
	menu_root.visible = true
