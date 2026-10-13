extends AnimatedSprite2D
class_name DeathBurst
## The death animation of a character (8 frames of 48 x 48 side by side, see tools/make_death_art.py and
## tools/make_death_light_art.py). Plays once.
##   - Heavy weapons: the explosion. The sprite removes itself when it is over.
##   - Light weapons: the body falls and collapses. The last frame, a bloody corpse, STAYS on the ground for
##     `corpse_time` seconds, then fades away. At most MAX_CORPSES exist at once.

const FRAME_SIZE: int = 48
const FRAME_COUNT: int = 8
const MAX_CORPSES: int = 50

var fps: float = 14.0
var sheet: Texture2D
## 0 = remove the sprite when the animation ends. > 0 = keep the last frame this many seconds, then fade out.
var corpse_time: float = 0.0
var fade_time: float = 2.0

var _holding: bool = false
var _hold_age: float = 0.0


## Creates the animation at a global position. `flip` mirrors it (the light death falls toward +x in the sheet).
static func play_at(
	tree: SceneTree, global_pos: Vector2, death_sheet: Texture2D, size_scale: float,
	flip: bool = false, persist: float = 0.0, z: int = 20, animation_fps: float = 14.0
) -> void:
	if death_sheet == null or tree == null or tree.current_scene == null:
		return

	if persist > 0.0:
		var existing: Array[Node] = tree.get_nodes_in_group("corpse")
		while existing.size() >= MAX_CORPSES:
			existing[0].queue_free()
			existing.remove_at(0)

	var burst := DeathBurst.new()
	burst.sheet = death_sheet
	burst.fps = animation_fps
	burst.flip_h = flip
	burst.corpse_time = persist
	burst.scale = Vector2.ONE * size_scale
	burst.z_index = z

	var scene: Node = tree.current_scene
	var scene_2d := scene as Node2D
	burst.position = scene_2d.to_local(global_pos) if scene_2d != null else global_pos
	scene.add_child.call_deferred(burst)


func _ready() -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", fps)
	frames.set_animation_loop(&"default", false)
	for i in FRAME_COUNT:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		frames.add_frame(&"default", atlas)
	sprite_frames = frames

	if corpse_time > 0.0:
		add_to_group("corpse")
		animation_finished.connect(_on_animation_finished)
	else:
		animation_finished.connect(queue_free)
	play(&"default")


func _on_animation_finished() -> void:
	_holding = true  # stays on the last frame: the corpse


func _process(delta: float) -> void:
	if not _holding:
		return
	_hold_age += delta
	if _hold_age > corpse_time:
		modulate.a = clampf(1.0 - (_hold_age - corpse_time) / fade_time, 0.0, 1.0)
		if modulate.a <= 0.0:
			queue_free()
