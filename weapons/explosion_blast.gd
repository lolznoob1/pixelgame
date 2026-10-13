extends AnimatedSprite2D
class_name ExplosionBlast
## The animated fireball (9 frames, 128 x 128, drawn for a 50 px radius). Plays once and removes itself.

const SHEET: Texture2D = preload("res://assets/weapons/explosion_sheet.png")
const FRAME_SIZE: int = 128
const FRAME_COUNT: int = 9
const DRAWN_RADIUS: float = 50.0

@export var fps: float = 18.0
## Radius the fireball should cover (the first damage radius); scales the art.
@export var fireball_radius: float = 50.0


func _ready() -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", fps)
	frames.set_animation_loop(&"default", false)
	for i in FRAME_COUNT:
		var atlas := AtlasTexture.new()
		atlas.atlas = SHEET
		atlas.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		frames.add_frame(&"default", atlas)
	sprite_frames = frames

	scale = Vector2.ONE * (fireball_radius / DRAWN_RADIUS)
	animation_finished.connect(queue_free)
	play(&"default")
