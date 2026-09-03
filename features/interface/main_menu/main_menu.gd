extends MarginContainer

@export var game_scene: PackedScene
@export var settings_scene: PackedScene

@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton

var _overlay_layer: CanvasLayer
var _settings_instance: Node = null


func _ready() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 10
	add_child(_overlay_layer)

	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	start_button.grab_focus()


func _on_start_pressed() -> void:
	if game_scene == null:
		push_warning("Main menu has no game scene assigned yet.")
		return

	var error := get_tree().change_scene_to_packed(game_scene)
	if error != OK:
		push_error("Could not load the game scene: %s" % error_string(error))


func _on_settings_pressed() -> void:
	if settings_scene == null:
		push_warning("Main menu has no settings scene assigned.")
		return
	if is_instance_valid(_settings_instance):
		return

	var settings := settings_scene.instantiate()
	settings.closed.connect(_on_settings_closed)
	_settings_instance = settings
	_overlay_layer.add_child(settings)

	_set_menu_interactive(false)


func _on_settings_closed() -> void:
	if is_instance_valid(_settings_instance):
		_settings_instance.queue_free()
	_settings_instance = null

	_set_menu_interactive(true)
	settings_button.grab_focus()


func _set_menu_interactive(enabled: bool) -> void:
	var mode := Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	for button in [start_button, settings_button, quit_button]:
		button.focus_mode = mode


func _on_quit_pressed() -> void:
	get_tree().quit()
