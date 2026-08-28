extends Control

signal closed

const BIND_BUTTON_WIDTH := 160

@onready var action_list: VBoxContainer = %ActionList
@onready var hint_label: Label = %HintLabel
@onready var reset_button: Button = %ResetButton
@onready var back_button: Button = %BackButton

var _listening_action := ""
var _bind_buttons: Dictionary = {}


func _ready() -> void:
	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(close)
	SettingsManager.keybinds_changed.connect(_refresh_labels)

	_build_rows()
	hint_label.text = "Select a binding, then press a key or button."
	if not _bind_buttons.is_empty():
		(_bind_buttons.values()[0] as Button).grab_focus()


func close() -> void:
	closed.emit()


func _build_rows() -> void:
	for child in action_list.get_children():
		child.queue_free()
	_bind_buttons.clear()

	for action in SettingsManager.REMAPPABLE_ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)

		var label := Label.new()
		label.text = SettingsManager.REMAPPABLE_ACTIONS[action]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var button := Button.new()
		button.custom_minimum_size.x = BIND_BUTTON_WIDTH
		button.text = SettingsManager.describe_event(
			SettingsManager.get_primary_event(action)
		)
		button.pressed.connect(_on_bind_pressed.bind(action))
		row.add_child(button)

		action_list.add_child(row)
		_bind_buttons[action] = button


func _refresh_labels() -> void:
	for action in _bind_buttons:
		var button: Button = _bind_buttons[action]
		if action == _listening_action:
			continue  # Leave the prompt up on the row we're waiting on.
		button.text = SettingsManager.describe_event(
			SettingsManager.get_primary_event(action)
		)


func _on_bind_pressed(action: String) -> void:
	if _listening_action != "":
		_stop_listening()

	_listening_action = action
	(_bind_buttons[action] as Button).text = "..."
	hint_label.text = "Press a key or button. Escape cancels, Delete unbinds."
	(_bind_buttons[action] as Button).release_focus()
	set_process_input(true)


func _stop_listening() -> void:
	var action := _listening_action
	_listening_action = ""
	set_process_input(false)
	hint_label.text = "Select a binding, then press a key or button."
	_refresh_labels()
	if _bind_buttons.has(action):
		(_bind_buttons[action] as Button).grab_focus()


func _input(event: InputEvent) -> void:
	if _listening_action == "":
		return

	# Stick and trigger axes never report is_pressed(), so handle them first.
	if event is InputEventJoypadMotion:
		if absf(event.axis_value) > 0.5:
			get_viewport().set_input_as_handled()
			SettingsManager.rebind_action(_listening_action, event)
			_stop_listening()
		return

	if not event.is_pressed() or event.is_echo():
		return

	get_viewport().set_input_as_handled()

	if event is InputEventKey:
		match event.keycode:
			KEY_ESCAPE:
				_stop_listening()
				return
			KEY_DELETE, KEY_BACKSPACE:
				SettingsManager.clear_action(_listening_action)
				_stop_listening()
				return

	if not SettingsManager.is_bindable(event):
		return

	SettingsManager.rebind_action(_listening_action, event)
	_stop_listening()


func _unhandled_input(event: InputEvent) -> void:
	if _listening_action != "":
		return
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		close()


func _on_reset_pressed() -> void:
	SettingsManager.reset_keybinds()
