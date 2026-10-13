extends Node2D
class_name BloodSpray
## The blood that sprays over the ground when a character is shot down (light weapons): hundreds of tiny red
## pixels in a random pattern, densest near the body and thinning out, sprayed mostly in the direction of the
## hit, with a few drips. It appears quickly, stays for a while and fades. At most MAX_SPRAYS exist at once.

const MAX_SPRAYS: int = 80
const COLORS: Array[Color] = [
	Color(0.93, 0.16, 0.20, 0.95),  # bright
	Color(0.93, 0.16, 0.20, 0.95),
	Color(0.75, 0.10, 0.15, 0.95),
	Color(0.75, 0.10, 0.15, 0.95),
	Color(0.52, 0.05, 0.10, 0.95),  # dark
	Color(0.40, 0.14, 0.12, 0.90),  # dried / brownish
]

@export var radius: float = 34.0
@export var lifetime: float = 18.0
@export var fade_time: float = 5.0
@export var pop_time: float = 0.14

var direction: Vector2 = Vector2.ZERO
var _pixels: Array[Dictionary] = []  # {"pos": Vector2i, "dist": float, "size": int, "color": Color}
var _age: float = 0.0


## `direction`: where the blood is sprayed to (zero = all around).
static func spawn(tree: SceneTree, global_pos: Vector2, spray_radius: float, spray_direction: Vector2 = Vector2.ZERO) -> void:
	var scene: Node = tree.current_scene if tree != null else null
	if scene == null:
		return

	var existing: Array[Node] = tree.get_nodes_in_group("blood_spray")
	while existing.size() >= MAX_SPRAYS:
		existing[0].queue_free()
		existing.remove_at(0)

	var spray := BloodSpray.new()
	spray.radius = spray_radius
	spray.direction = spray_direction
	spray.z_index = -5  # above the background (z -10), below characters (z 0)

	var scene_2d := scene as Node2D
	spray.position = scene_2d.to_local(global_pos) if scene_2d != null else global_pos
	scene.add_child.call_deferred(spray)


func _enter_tree() -> void:
	add_to_group("blood_spray")


func _ready() -> void:
	var seen: Dictionary = {}
	var aimed: bool = not direction.is_zero_approx()
	var base_angle: float = direction.angle() if aimed else 0.0

	# The fine mist: mostly in the direction of the hit, the rest all around.
	for i in randi_range(150, 220):
		var angle: float = randf() * TAU
		if aimed and randf() < 0.6:
			angle = base_angle + randf_range(-0.9, 0.9)
		var distance: float = radius * pow(randf(), 0.65)  # more near the middle
		_add_pixel(Vector2.from_angle(angle) * distance, seen, 2 if randf() < 0.1 else 1, COLORS[randi() % COLORS.size()])

	# Drips and streaks running outward.
	for i in randi_range(4, 7):
		var angle: float = base_angle + randf_range(-1.0, 1.0) if aimed else randf() * TAU
		var length: float = radius * randf_range(0.3, 0.7)
		var step: float = 2.0
		while step < length:
			_add_pixel(Vector2.from_angle(angle) * step, seen, 1, COLORS[2 + randi() % 3])
			step += 1.0


# The blood lies on the ground, so it is flattened (y * 0.7).
func _add_pixel(pos: Vector2, seen: Dictionary, size: int, color: Color) -> void:
	var cell := Vector2i(roundi(pos.x), roundi(pos.y * 0.7))
	if seen.has(cell):
		return
	seen[cell] = true
	_pixels.append({"pos": cell, "dist": pos.length(), "size": size, "color": color})


func _process(delta: float) -> void:
	_age += delta
	if _age > lifetime + fade_time:
		queue_free()
		return
	if _age < pop_time + 0.05 or _age > lifetime:
		queue_redraw()


func _draw() -> void:
	var spread: float = clampf(_age / pop_time, 0.0, 1.0) * (radius * 1.1)
	var alpha: float = 1.0
	if _age > lifetime:
		alpha = clampf(1.0 - (_age - lifetime) / fade_time, 0.0, 1.0)

	for pixel in _pixels:
		if float(pixel["dist"]) > spread:
			continue
		var color: Color = pixel["color"]
		color.a *= alpha
		var size: float = float(pixel["size"])
		draw_rect(Rect2(Vector2(pixel["pos"]), Vector2(size, size)), color)
