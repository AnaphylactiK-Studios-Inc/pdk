extends Control

signal closed

@export var controls_scene: PackedScene

@onready var master_slider: HSlider = %MasterSlider
@onready var master_value: Label = %MasterValue
@onready var music_slider: HSlider = %MusicSlider
@onready var music_value: Label = %MusicValue
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_value: Label = %SfxValue

@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var vsync_check: CheckButton = %VsyncCheck

@onready var controls_button: Button = %ControlsButton
@onready var reset_button: Button = %ResetButton
@onready var back_button: Button = %BackButton

var _syncing := false
var _controls_instance: Node = null


func _ready() -> void:
	_populate_dropdowns()

	master_slider.value_changed.connect(_on_volume_changed.bind("master"))
	music_slider.value_changed.connect(_on_volume_changed.bind("music"))
	sfx_slider.value_changed.connect(_on_volume_changed.bind("sfx"))

	master_slider.drag_ended.connect(_on_slider_released.bind("master"))
	music_slider.drag_ended.connect(_on_slider_released.bind("music"))
	sfx_slider.drag_ended.connect(_on_slider_released.bind("sfx"))

	window_mode_option.item_selected.connect(_on_window_mode_selected)
	resolution_option.item_selected.connect(_on_resolution_selected)
	vsync_check.toggled.connect(_on_vsync_toggled)

	controls_button.pressed.connect(_on_controls_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(close)

	SettingsManager.settings_changed.connect(_sync_from_manager)

	_sync_from_manager()
	master_slider.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	# Only when no submenu is up.
	if is_instance_valid(_controls_instance):
		return
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		close()


func close() -> void:
	closed.emit()


# --- Building the UI ---

func _populate_dropdowns() -> void:
	window_mode_option.clear()
	window_mode_option.add_item("Windowed", SettingsManager.WindowMode.WINDOWED)
	window_mode_option.add_item("Borderless", SettingsManager.WindowMode.BORDERLESS)
	window_mode_option.add_item("Fullscreen", SettingsManager.WindowMode.FULLSCREEN)

	resolution_option.clear()
	for i in SettingsManager.RESOLUTIONS.size():
		var res: Vector2i = SettingsManager.RESOLUTIONS[i]
		resolution_option.add_item("%d x %d" % [res.x, res.y], i)


func _sync_from_manager() -> void:
	_syncing = true

	master_slider.value = SettingsManager.volumes["master"]
	music_slider.value = SettingsManager.volumes["music"]
	sfx_slider.value = SettingsManager.volumes["sfx"]
	_update_value_labels()

	var mode_index: int = window_mode_option.get_item_index(SettingsManager.window_mode)
	if mode_index != -1:
		window_mode_option.select(mode_index)

	while resolution_option.get_item_count() > SettingsManager.RESOLUTIONS.size():
		resolution_option.remove_item(resolution_option.get_item_count() - 1)

	var res_index: int = SettingsManager.RESOLUTIONS.find(SettingsManager.resolution)
	if res_index == -1:
		var label: String = "%d x %d" % [SettingsManager.resolution.x, SettingsManager.resolution.y]
		resolution_option.add_item(label, SettingsManager.RESOLUTIONS.size())
		res_index = resolution_option.get_item_count() - 1
	resolution_option.select(res_index)

	resolution_option.disabled = \
		SettingsManager.window_mode != SettingsManager.WindowMode.WINDOWED

	vsync_check.button_pressed = SettingsManager.vsync

	_syncing = false


func _update_value_labels() -> void:
	master_value.text = "%d%%" % roundi(master_slider.value * 100.0)
	music_value.text = "%d%%" % roundi(music_slider.value * 100.0)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value * 100.0)


# --- Handlers ---

func _on_volume_changed(value: float, key: String) -> void:
	_update_value_labels()
	if _syncing:
		return
	SettingsManager.set_volume(key, value)


func _on_slider_released(value_changed: bool, key: String) -> void:
	if value_changed:
		SettingsManager.preview_volume(key)


func _on_window_mode_selected(index: int) -> void:
	if _syncing:
		return
	SettingsManager.set_window_mode(window_mode_option.get_item_id(index))


func _on_resolution_selected(index: int) -> void:
	if _syncing:
		return
	var id := resolution_option.get_item_id(index)
	var count: int = SettingsManager.RESOLUTIONS.size()
	if id < 0 or id >= count:
		return  # The "current, unlisted" entry. Nothing to change.
	var res: Vector2i = SettingsManager.RESOLUTIONS[id]
	SettingsManager.set_resolution(res)


func _on_vsync_toggled(pressed: bool) -> void:
	if _syncing:
		return
	SettingsManager.set_vsync(pressed)


func _on_reset_pressed() -> void:
	SettingsManager.reset_to_defaults()


func _on_controls_pressed() -> void:
	if controls_scene == null:
		push_warning("Settings panel has no controls scene assigned.")
		return
	if is_instance_valid(_controls_instance):
		return

	var controls := controls_scene.instantiate()
	controls.closed.connect(_on_controls_closed)
	_controls_instance = controls
	add_child(controls)


func _on_controls_closed() -> void:
	if is_instance_valid(_controls_instance):
		_controls_instance.queue_free()
	_controls_instance = null
	controls_button.grab_focus()
