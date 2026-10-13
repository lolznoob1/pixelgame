extends RefCounted
class_name SheetAnimations
## Helper: adds one row of a sprite sheet to a SpriteFrames as an animation.


## Does nothing if the animation already exists, so it is safe to call every time.
static func add_row(
	frames: SpriteFrames, anim: StringName, texture: Texture2D,
	row: int, count: int, speed: float, loop: bool, frame_size: int = 16
) -> void:
	if frames == null or texture == null or frames.has_animation(anim):
		return

	frames.add_animation(anim)
	frames.set_animation_loop(anim, loop)
	frames.set_animation_speed(anim, speed)
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * frame_size, row * frame_size, frame_size, frame_size)
		frames.add_frame(anim, atlas)
