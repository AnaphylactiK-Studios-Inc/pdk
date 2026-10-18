extends WireGridEndpoint
class_name WireGridSource

@export var source_texture: Texture2D:
	set(value):
		source_texture = value
		texture = value

func _ready():
	super._ready()
	texture = source_texture
