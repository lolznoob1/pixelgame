extends Node2D
class_name GooSplat
## Red goo left on the ground when a character explodes: a flattened puddle with blobs, streaks and drops,
## drawn pixel by pixel in a random pattern inside a circle (same idea as WaterSplash and GroundCracks).
## It spreads out quickly, stays for a while and fades. At most MAX_SPLATS exist at once: when there
## are more, the oldest ones disappear, so a big wave doesn't slow the game down.

const MAX_SPLATS: int = 80
const GOO_HI: Color = Color(0.96, 0.31, 0.31, 0.95)
const GOO: Color = Color(0.81, 0.11, 0.16, 0.95)
const GOO_MID: Color = Color(0.63, 0.07, 0.13, 0.95)
const GOO_DK: Color = Color(0.44, 0.05, 0.11, 0.95)

@export var radius: float = 20.0
@export var lifetime: float = 14.0
@export var fade_time: float = 4.0
@export var pop_time: float = 0.12

var _pixels: Array[Dictionary] = []  # {"pos": Vector2i, "dist": float, "color": Color}
var _age: float = 0.0


static func spawn(tree: SceneTree, global_pos: Vector2, splat_radius: float) -> void:
	var scene: Node = tree.current_scene if tree != null else null
	if scene == null:
		return

	# Keep the number of splats under control: the oldest one goes.
	var existing: Array[Node] = tree.get_nodes_in_group("goo_splat")
	while existing.size() >= MAX_SPLATS:
		existing[0].queue_free()
		existing.remove_at(0)

	var splat := GooSplat.new()
	splat.radius = splat_radius
	splat.z_index = -5  # above the background (z -10), below characters (z 0)

	var scene_2d := scene as Node2D
	splat.position = scene_2d.to_local(global_pos) if scene_2d != null else global_pos
	scene.add_child.call_deferred(splat)


func _enter_tree() -> void:
	add_to_group("goo_splat")


func _ready() -> void:
	var seen: Dictionary = {}

	# Main puddle: a flattened disc, darker toward the edge.
	var core: float = radius * 0.5
	_fill_blob(Vector2.ZERO, core, seen)

	# Blobs around it.
	for i in randi_range(6, 9):
		var angle: float = randf() * TAU
		var distance: float = radius * randf_range(0.35, 0.85)
		_fill_blob(Vector2.from_angle(angle) * distance, randf_range(2.0, 5.0), seen)

	# Streaks running outward.
	for i in randi_range(5, 8):
		var angle: float = randf() * TAU
		var length: float = radius * randf_range(0.7, 1.0)
		var step: float = 0.0
		while step < length:
			_add_pixel(Vector2.from_angle(angle) * step, seen, GOO_MID)
			step += 1.0

	# Single drops further out.
	for i in randi_range(10, 16):
		var angle: float = randf() * TAU
		_add_pixel(Vector2.from_angle(angle) * radius * randf_range(0.6, 1.15), seen, GOO if randf() < 0.6 else GOO_HI)


func _fill_blob(center: Vector2, blob_radius: float, seen: Dictionary) -> void:
	var span: int = ceili(blob_radius)
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var offset := Vector2(dx, dy)
			var depth: float = 1.0 - offset.length() / maxf(blob_radius, 0.1)
			if depth <= 0.0:
				continue
			var color: Color = GOO_DK
			if depth > 0.6:
				color = GOO_HI if randf() < 0.18 else GOO
			elif depth > 0.3:
				color = GOO
			elif depth > 0.12:
				color = GOO_MID
			_add_pixel(center + offset, seen, color)


# The splat lies on the ground, so it is flattened (y * 0.6).
func _add_pixel(pos: Vector2, seen: Dictionary, color: Color) -> void:
	var cell := Vector2i(roundi(pos.x), roundi(pos.y * 0.6))
	if seen.has(cell):
		return
	seen[cell] = true
	_pixels.append({"pos": cell, "dist": pos.length(), "color": color})


func _process(delta: float) -> void:
	_age += delta
	if _age > lifetime + fade_time:
		queue_free()
		return
	# Redraw only while something changes (spreading and fading).
	if _age < pop_time + 0.05 or _age > lifetime:
		queue_redraw()


func _draw() -> void:
	var spread: float = clampf(_age / pop_time, 0.0, 1.0) * (radius * 1.2)
	var alpha: float = 1.0
	if _age > lifetime:
		alpha = clampf(1.0 - (_age - lifetime) / fade_time, 0.0, 1.0)

	for pixel in _pixels:
		if float(pixel["dist"]) > spread:
			continue
		var color: Color = pixel["color"]
		color.a *= alpha
		draw_rect(Rect2(Vector2(pixel["pos"]), Vector2.ONE), color)
