extends RefCounted
class_name DirectionalFacing
## Keeps track of which of 8 directions a character faces and turns it step by step,
## so a character that reverses direction visibly turns around (south -> east -> north ...).

const DIRS: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const SECTOR: float = TAU / 8.0

## Seconds per 45 degree step of a turn. A full 180 degree turn takes 4 steps.
var step_time: float = 0.035
## Current direction index (into DIRS). Starts facing south, toward the camera.
var index: int = 2

var _target: int = 2
var _timer: float = 0.0


## Adds "<anim>_<dir>" animations (idle_e, idle_se, ...) to the SpriteFrames. Safe to call for
## every instance: frames are shared, so it only builds them the first time.
static func build_animations(frames: SpriteFrames, sheet: DirectionalSheet) -> void:
	if frames == null or sheet == null or sheet.texture == null:
		return

	var size: int = sheet.frame_size
	for block in sheet.anim_names.size():
		var base: StringName = StringName(sheet.anim_names[block])
		var count: int = sheet.frame_counts[block]
		var speed: float = frames.get_animation_speed(base) if frames.has_animation(base) else 5.0

		for dir_index in DIRS.size():
			var anim: StringName = StringName("%s_%s" % [base, DIRS[dir_index]])
			if frames.has_animation(anim):
				continue
			frames.add_animation(anim)
			frames.set_animation_loop(anim, true)
			frames.set_animation_speed(anim, speed)
			for frame in count:
				var atlas := AtlasTexture.new()
				atlas.atlas = sheet.texture
				atlas.region = Rect2(frame * size, (block * 8 + dir_index) * size, size, size)
				frames.add_frame(anim, atlas)


## Plays an animation, keeping the walk-cycle position when only the direction changes
## (walk_e -> walk_se), so turning doesn't restart the steps.
static func play_keep_frame(sprite: AnimatedSprite2D, anim: StringName, speed_scale: float = 1.0) -> void:
	sprite.speed_scale = speed_scale
	if sprite.animation == anim and sprite.is_playing():
		return

	var frames: SpriteFrames = sprite.sprite_frames
	if frames == null or not frames.has_animation(anim):
		return

	var old_base: String = String(sprite.animation).rsplit("_", true, 1)[0]
	var new_base: String = String(anim).rsplit("_", true, 1)[0]
	var old_frame: int = sprite.frame
	var old_progress: float = sprite.frame_progress

	sprite.play(anim)
	if old_base == new_base:
		sprite.set_frame_and_progress(mini(old_frame, frames.get_frame_count(anim) - 1), old_progress)


## Sets the direction the character should face. Small wobbles near a sector border are ignored.
func face_direction(direction: Vector2) -> void:
	if direction.length_squared() < 0.0001:
		return

	var sector: float = direction.angle() / SECTOR
	var wanted: int = posmod(roundi(sector), 8)
	if wanted == _target:
		return

	var delta: float = fposmod(sector - float(_target) + 4.0, 8.0) - 4.0
	if absf(delta) > 0.65:
		_target = wanted


## Jumps to a direction without the turning steps.
func snap_to(direction: Vector2) -> void:
	if direction.length_squared() < 0.0001:
		return
	index = posmod(roundi(direction.angle() / SECTOR), 8)
	_target = index
	_timer = 0.0


## Advances the turn. Call every frame.
func update(delta: float) -> void:
	if index == _target:
		_timer = 0.0
		return

	_timer += delta
	while _timer >= step_time and index != _target:
		_timer -= step_time
		var distance: int = posmod(_target - index, 8)
		index = posmod(index + (1 if distance <= 4 else -1), 8)


func anim_name(base: StringName) -> StringName:
	return StringName("%s_%s" % [base, DIRS[index]])
