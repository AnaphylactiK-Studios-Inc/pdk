extends Label

## Build watermark text, e.g. "Peanut & Dreadnought Killer | Alpha 0.0.1". The
## number lives in Project Settings > Application > Config > Version.
## Version number stays numeric because of Windows exports.

const RELEASE_STAGE := "Alpha"


func _ready() -> void:
	text = "%s\n%s %s" % [
		ProjectSettings.get_setting("application/config/name", ""),
		RELEASE_STAGE,
		ProjectSettings.get_setting("application/config/version", ""),
	]
