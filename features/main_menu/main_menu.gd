extends MarginContainer

## The scene to load when the player presses Start.
## Drag a gameplay scene onto this property in the Inspector once one exists.
@export var game_scene: PackedScene

@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
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
	print("Test")

func _on_quit_pressed() -> void:
	get_tree().quit()
