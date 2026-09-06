extends MarginContainer

## The scene to load when the player presses Start.
## Drag a gameplay scene onto this property in the Inspector once one exists.
@export var game_scene: PackedScene
@export var settings_scene: PackedScene

@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton

## Overlays live on their own CanvasLayer so this MarginContainer doesn't try to
## lay them out, and so they always draw above the menu regardless of tree order.
var _overlay_layer: CanvasLayer
var _settings_instance: Node = null


func _ready() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 10
	add_child(_overlay_layer)

	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Focus the first button so the menu can be used with a keyboard or gamepad.
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
		return  # Already open; a double-click shouldn't stack two panels.

	var settings := settings_scene.instantiate()
	# Connect before add_child: add_child runs _ready, and if the panel ever
	# decides to close itself there, a connection made afterwards misses it.
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


## While an overlay is up, the menu buttons shouldn't be reachable by Tab or by
## a gamepad stick. The overlay's own full-rect Control blocks the mouse.
func _set_menu_interactive(enabled: bool) -> void:
	var mode := Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	for button in [start_button, settings_button, quit_button]:
		button.focus_mode = mode


func _on_quit_pressed() -> void:
	get_tree().quit()
