extends Node

@export var bank_paths: Array[String] = [
	"res://audio/banks/Master.bank",
	"res://audio/banks/Master.strings.bank",
]

@export var enabled := true

signal banks_loaded

var has_banks := false

var _banks: Array = []


func _ready() -> void:
	await _load_all()
	has_banks = not _banks.is_empty()
	banks_loaded.emit()
	SettingsManager.bind_audio()


func _load_all() -> void:
	if not enabled:
		print_verbose("AudioManager: disabled, skipping bank load.")
		return

	for path in bank_paths:
		if not FileAccess.file_exists(path):
			print_verbose("AudioManager: bank not present yet, skipping %s" % path)
			continue

		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			var size := file.get_length()
			file.close()
			if size < 1024:
				push_warning(
					"Bank looks like a placeholder or LFS pointer (%d bytes): %s"
					% [size, path]
				)
				continue

		var bank: FmodBank = FmodServer.load_bank(
			path, FmodServer.FMOD_STUDIO_LOAD_BANK_NORMAL
		)
		if bank == null:
			push_error("Could not load bank: %s" % path)
			continue

		while bank.get_loading_state() == FmodServer.FMOD_STUDIO_LOADING_STATE_LOADING:
			await get_tree().process_frame

		_banks.append(bank)

	if _banks.is_empty():
		print_verbose("AudioManager: no banks loaded, running without audio.")
