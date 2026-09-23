class_name MenuAudio
extends RefCounted

## Menu sound wiring. A panel calls wire() once with its root node and the whole
## subtree gets navigation and press sounds; rows built at runtime just need
## another wire() call on their container, since already-wired nodes are skipped.
##
## The events themselves live in AudioManager.UI_EVENTS, keyed by the roles below.

const MOVE := &"move"
const CLICK := &"click"
const BACK := &"back"
const CONFIRM := &"confirm"
const BLOCKED := &"blocked"

## Metadata a scene or script can set on a control to change what it plays when
## pressed — any role above, or &"none" to keep it silent. Back buttons use this
## so their own close() can play the back sound instead of a click.
const ROLE_META := &"menu_audio_role"

## Marks a node this class has already connected, so wire() can be called again
## after a rebuild without stacking duplicate connections.
const WIRED_META := &"menu_audio_wired"

## Set between drag_started and drag_ended so a mouse drag doesn't tick per pixel.
const DRAGGING_META := &"menu_audio_dragging"

## Focus the game moved itself — opening a panel, rebuilding a list, returning
## from a submenu — isn't the player navigating, so hold sounds off briefly.
const PROGRAMMATIC_FOCUS_QUIET := 0.15

## Holding a direction repeats faster than the ear can separate the clicks.
const MOVE_MIN_INTERVAL := 0.05

static var _quiet_until_msec := 0
static var _last_move_msec := -1000


# --- Playing ---

static func play(role: StringName) -> void:
	AudioManager.play_ui(role)


static func move() -> void:
	var now := Time.get_ticks_msec()
	if now < _quiet_until_msec:
		return
	if now - _last_move_msec < roundi(MOVE_MIN_INTERVAL * 1000.0):
		return
	_last_move_msec = now
	AudioManager.play_ui(MOVE)


static func click() -> void:
	AudioManager.play_ui(CLICK)


static func back() -> void:
	AudioManager.play_ui(BACK)


static func confirm() -> void:
	AudioManager.play_ui(CONFIRM)


## For input the menu deliberately refused: a button with nothing behind it, a
## key the rebinder won't take.
static func blocked() -> void:
	AudioManager.play_ui(BLOCKED)


## Suppresses navigation sounds for a moment. Call before grab_focus() from
## code, so the player only hears focus moves they asked for.
static func quiet(seconds := PROGRAMMATIC_FOCUS_QUIET) -> void:
	_quiet_until_msec = maxi(
		_quiet_until_msec, Time.get_ticks_msec() + roundi(seconds * 1000.0)
	)


## Moves focus without the accompanying navigation sound.
static func focus_silently(control: Control) -> void:
	if not is_instance_valid(control):
		return
	quiet()
	control.grab_focus()


# --- Wiring ---

## Connects every focusable control, button, slider and dialog under `root`.
## Safe to call again after rebuilding part of the tree.
static func wire(root: Node) -> void:
	_wire_node(root)
	quiet()


static func _wire_node(node: Node) -> void:
	if not node.get_meta(WIRED_META, false):
		node.set_meta(WIRED_META, true)

		if node is AcceptDialog:
			_wire_dialog(node)
		elif node is BaseButton:
			_wire_button(node)
		elif node is Range:
			_wire_range(node)

		if node is Control and node.focus_mode != Control.FOCUS_NONE:
			node.focus_entered.connect(MenuAudio.move)

	for child in node.get_children():
		_wire_node(child)


static func _wire_button(button: BaseButton) -> void:
	button.pressed.connect(MenuAudio._on_button_pressed.bind(button))
	# A dropdown's press opens the popup; committing a choice is the confirm.
	if button is OptionButton:
		button.item_selected.connect(MenuAudio._on_item_selected)


static func _wire_range(range_control: Range) -> void:
	range_control.value_changed.connect(
		MenuAudio._on_range_value_changed.bind(range_control)
	)
	if range_control is Slider:
		range_control.drag_started.connect(
			MenuAudio._on_drag_started.bind(range_control)
		)
		range_control.drag_ended.connect(MenuAudio._on_drag_ended.bind(range_control))


## The dialog's own confirmed/canceled cover both its buttons and the Escape
## key, so OK and Cancel are muted to avoid doubling up.
static func _wire_dialog(dialog: AcceptDialog) -> void:
	for button in [dialog.get_ok_button(), dialog.get_cancel_button()]:
		if button != null:
			button.set_meta(ROLE_META, &"none")

	dialog.confirmed.connect(MenuAudio.confirm)
	dialog.canceled.connect(MenuAudio.back)
	# Popping up steals focus onto OK, which isn't the player navigating.
	dialog.about_to_popup.connect(MenuAudio.quiet.bind(PROGRAMMATIC_FOCUS_QUIET))


# --- Handlers ---

static func _on_button_pressed(button: BaseButton) -> void:
	var role: StringName = button.get_meta(ROLE_META, CLICK)
	if role == &"none":
		return
	AudioManager.play_ui(role)


static func _on_item_selected(_index: int) -> void:
	confirm()


static func _on_range_value_changed(_value: float, range_control: Range) -> void:
	# Mouse drags stay silent: they'd tick per pixel, and the settings panel
	# previews the new volume when the drag ends.
	if range_control.get_meta(DRAGGING_META, false):
		return
	move()


static func _on_drag_started(range_control: Range) -> void:
	range_control.set_meta(DRAGGING_META, true)


static func _on_drag_ended(_value_changed: bool, range_control: Range) -> void:
	range_control.set_meta(DRAGGING_META, false)
