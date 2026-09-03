extends Control

signal closed

const BIND_BUTTON_WIDTH := 160

@onready var kbm_tab_button: Button = %KbmTabButton
@onready var controller_tab_button: Button = %ControllerTabButton
@onready var action_list: VBoxContainer = %ActionList
@onready var hint_label: Label = %HintLabel
@onready var reset_button: Button = %ResetButton
@onready var back_button: Button = %BackButton
@onready var reset_confirm_dialog: ConfirmationDialog = %ResetConfirmDialog

@onready var mouse_sensitivity_slider: HSlider = %MouseSensitivitySlider
@onready var mouse_sensitivity_value: Label = %MouseSensitivityValue
@onready var stick_sensitivity_x_slider: HSlider = %StickSensitivityXSlider
@onready var stick_sensitivity_x_value: Label = %StickSensitivityXValue
@onready var stick_sensitivity_y_slider: HSlider = %StickSensitivityYSlider
@onready var stick_sensitivity_y_value: Label = %StickSensitivityYValue
@onready var controller_style_option: OptionButton = %ControllerStyleOption
@onready var sprint_toggle_button: CheckButton = %SprintToggleButton
@onready var crawl_toggle_button: CheckButton = %CrawlToggleButton

var _listening_action := ""
var _active_family: int = SettingsManager.BindFamily.KBM
var _bind_buttons: Dictionary = {}
var _syncing := false


func _ready() -> void:
	kbm_tab_button.pressed.connect(_on_tab_pressed.bind(SettingsManager.BindFamily.KBM))
	controller_tab_button.pressed.connect(_on_tab_pressed.bind(SettingsManager.BindFamily.JOY))
	reset_button.pressed.connect(reset_confirm_dialog.popup_centered)
	reset_confirm_dialog.confirmed.connect(_on_reset_confirmed)
	back_button.pressed.connect(close)

	mouse_sensitivity_slider.value_changed.connect(_on_mouse_sensitivity_changed)
	stick_sensitivity_x_slider.value_changed.connect(_on_stick_sensitivity_x_changed)
	stick_sensitivity_y_slider.value_changed.connect(_on_stick_sensitivity_y_changed)
	sprint_toggle_button.toggled.connect(_on_sprint_toggle_changed)
	crawl_toggle_button.toggled.connect(_on_crawl_toggle_changed)
	_populate_controller_style_dropdown()
	controller_style_option.item_selected.connect(_on_controller_style_selected)

	SettingsManager.keybinds_changed.connect(_refresh_labels)
	SettingsManager.controller_style_changed.connect(_refresh_labels)
	SettingsManager.settings_changed.connect(_sync_sensitivity_from_manager)

	_set_active_tab(SettingsManager.BindFamily.KBM)
	_sync_sensitivity_from_manager()


func close() -> void:
	closed.emit()


func _set_active_tab(family: int) -> void:
	if _listening_action != "":
		_stop_listening()

	_active_family = family
	kbm_tab_button.button_pressed = family == SettingsManager.BindFamily.KBM
	controller_tab_button.button_pressed = family == SettingsManager.BindFamily.JOY

	_build_rows()
	hint_label.text = "Select a binding, then press a key or button."


func _on_tab_pressed(family: int) -> void:
	if family == _active_family:
		return
	_set_active_tab(family)


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
			SettingsManager.get_event_for_family(action, _active_family)
		)
		button.pressed.connect(_on_bind_pressed.bind(action))
		row.add_child(button)

		action_list.add_child(row)
		_bind_buttons[action] = button

	if not _bind_buttons.is_empty():
		(_bind_buttons.values()[0] as Button).grab_focus()


func _refresh_labels() -> void:
	for action in _bind_buttons:
		var button: Button = _bind_buttons[action]
		if action == _listening_action:
			continue  # Leave the prompt up on the row we're waiting on.
		button.text = SettingsManager.describe_event(
			SettingsManager.get_event_for_family(action, _active_family)
		)


func _on_bind_pressed(action: String) -> void:
	if _listening_action != "":
		_stop_listening()

	_listening_action = action
	(_bind_buttons[action] as Button).text = "..."
	hint_label.text = (
		"Press a controller button or move a stick. Escape cancels, Delete unbinds."
		if _active_family == SettingsManager.BindFamily.JOY
		else "Press a key or mouse button. Escape cancels, Delete unbinds."
	)
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

	if event is InputEventJoypadMotion:
		if _active_family != SettingsManager.BindFamily.JOY:
			return
		if absf(event.axis_value) > 0.5:
			get_viewport().set_input_as_handled()
			SettingsManager.rebind_action(_listening_action, event)
			_stop_listening()
		return

	if not event.is_pressed() or event.is_echo():
		return

	if event is InputEventKey:
		match event.keycode:
			KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_stop_listening()
				return
			KEY_DELETE, KEY_BACKSPACE:
				get_viewport().set_input_as_handled()
				SettingsManager.clear_action(_listening_action, _active_family)
				_stop_listening()
				return

	if not SettingsManager.is_bindable(event):
		return

	# Ignore input from the family that isn't the active tab.
	if SettingsManager.get_event_family(event) != _active_family:
		return

	get_viewport().set_input_as_handled()
	SettingsManager.rebind_action(_listening_action, event)
	_stop_listening()


func _unhandled_input(event: InputEvent) -> void:
	if _listening_action != "":
		return
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		close()


func _on_reset_confirmed() -> void:
	SettingsManager.reset_controls_defaults()
	_build_rows()
	_sync_sensitivity_from_manager()


# --- Sensitivity ---

func _populate_controller_style_dropdown() -> void:
	controller_style_option.clear()
	for style in SettingsManager.CONTROLLER_STYLE_NAMES:
		controller_style_option.add_item(SettingsManager.CONTROLLER_STYLE_NAMES[style], style)


func _sync_sensitivity_from_manager() -> void:
	_syncing = true

	mouse_sensitivity_slider.value = SettingsManager.mouse_sensitivity
	stick_sensitivity_x_slider.value = SettingsManager.stick_sensitivity_x
	stick_sensitivity_y_slider.value = SettingsManager.stick_sensitivity_y
	sprint_toggle_button.button_pressed = SettingsManager.sprint_toggle
	crawl_toggle_button.button_pressed = SettingsManager.crawl_toggle
	_update_sensitivity_labels()

	var style_index: int = controller_style_option.get_item_index(
		SettingsManager.controller_style_override
	)
	if style_index != -1:
		controller_style_option.select(style_index)

	_syncing = false


func _update_sensitivity_labels() -> void:
	mouse_sensitivity_value.text = "%d%%" % roundi(mouse_sensitivity_slider.value * 100.0)
	stick_sensitivity_x_value.text = "%d%%" % roundi(stick_sensitivity_x_slider.value * 100.0)
	stick_sensitivity_y_value.text = "%d%%" % roundi(stick_sensitivity_y_slider.value * 100.0)
	# The switch reads as its own label: what the button is set to right now.
	sprint_toggle_button.text = "Toggle" if sprint_toggle_button.button_pressed else "Hold"
	crawl_toggle_button.text = "Toggle" if crawl_toggle_button.button_pressed else "Hold"


func _on_mouse_sensitivity_changed(value: float) -> void:
	_update_sensitivity_labels()
	if _syncing:
		return
	SettingsManager.set_mouse_sensitivity(value)


func _on_stick_sensitivity_x_changed(value: float) -> void:
	_update_sensitivity_labels()
	if _syncing:
		return
	SettingsManager.set_stick_sensitivity_x(value)


func _on_stick_sensitivity_y_changed(value: float) -> void:
	_update_sensitivity_labels()
	if _syncing:
		return
	SettingsManager.set_stick_sensitivity_y(value)


func _on_sprint_toggle_changed(enabled: bool) -> void:
	_update_sensitivity_labels()
	if _syncing:
		return
	SettingsManager.set_sprint_toggle(enabled)


func _on_crawl_toggle_changed(enabled: bool) -> void:
	_update_sensitivity_labels()
	if _syncing:
		return
	SettingsManager.set_crawl_toggle(enabled)


func _on_controller_style_selected(index: int) -> void:
	if _syncing:
		return
	SettingsManager.set_controller_style(controller_style_option.get_item_id(index))
