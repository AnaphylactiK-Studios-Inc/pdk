extends WireGridEndpoint
class_name WireGridDestination

@export var on_texture: Texture2D
@export var off_texture: Texture2D

@export var powered := false:
	set(value):
		if powered == value:
			return

		powered = value
		update_texture()

func _ready():
	super._ready()
	update_texture()

func update_texture():
	texture = on_texture if powered else off_texture
