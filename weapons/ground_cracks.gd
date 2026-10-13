extends Node2D
class_name GroundCracks
## Small cracks in the ground, scattered randomly in a circle (same idea as WaterSplash):
## 6-9 crooked cracks run outward from the middle, some with a short side branch. They are
## drawn pixel by pixel, appear from the middle outward, stay a few seconds and fade away.

const CRACK_COLOR: Color = Color(0.12, 0.09, 0.14, 0.9)
const EDGE_COLOR: Color = Color(0.5, 0.45, 0.45, 0.65)

## Radius of the circle the cracks fill (the jump's knockback zone).
@export var radius: float = 15.0
@export var min_cracks: int = 6
@export var max_cracks: int = 9
## Seconds the cracks stay before they start to fade.
@export var lifetime: float = 6.0
@export var fade_time: float = 2.0
## Seconds the cracks need to spread from the middle to the edge.
@export var pop_time: float = 0.18

var _pixels: Array[Dictionary] = []  # {"pos": Vector2i, "dist": float, "edge": bool}
var _age: float = 0.0


## Creates cracks in the current scene at a global position.
static func spawn(tree: SceneTree, global_pos: Vector2, crack_radius: float) -> void:
	var scene: Node = tree.current_scene if tree != null else null
	if scene == null:
		return

	var cracks := GroundCracks.new()
	cracks.radius = crack_radius
	cracks.z_index = -5  # above the background (z -10), below characters (z 0)

	var scene_2d := scene as Node2D
	cracks.position = scene_2d.to_local(global_pos) if scene_2d != null else global_pos
	scene.add_child.call_deferred(cracks)


func _ready() -> void:
	_generate()


func _generate() -> void:
	var seen: Dictionary = {}
	var count: int = randi_range(min_cracks, max_cracks)
	var base_angle: float = randf() * TAU

	for i in count:
		# Spread around the circle, but jittered, so the pattern is different every time.
		var angle: float = base_angle + TAU * float(i) / float(count) + randf_range(-0.35, 0.35)
		var position_now: Vector2 = Vector2.from_angle(angle) * randf_range(1.0, 3.0)
		var reach: float = radius * randf_range(0.55, 1.0)
		var segments: int = randi_range(2, 4)

		for segment in segments:
			var length: float = reach / float(segments) * randf_range(0.8, 1.3)
			angle += randf_range(-0.55, 0.55)
			var next: Vector2 = _clamp_to_circle(position_now + Vector2.from_angle(angle) * length)
			_add_line(position_now, next, seen)

			# Sometimes a short side crack.
			if randf() < 0.3:
				var side: float = angle + (1.0 if randf() < 0.5 else -1.0) * randf_range(0.7, 1.2)
				_add_line(next, _clamp_to_circle(next + Vector2.from_angle(side) * randf_range(2.0, 4.0)), seen)

			position_now = next


func _clamp_to_circle(point: Vector2) -> Vector2:
	if point.length() > radius:
		return point.normalized() * radius
	return point


# Pixel-perfect line (Bresenham).
func _add_line(from: Vector2, to: Vector2, seen: Dictionary) -> void:
	var a := Vector2i(roundi(from.x), roundi(from.y))
	var b := Vector2i(roundi(to.x), roundi(to.y))
	var dx: int = absi(b.x - a.x)
	var dy: int = -absi(b.y - a.y)
	var step_x: int = 1 if a.x < b.x else -1
	var step_y: int = 1 if a.y < b.y else -1
	var error: int = dx + dy
	var point: Vector2i = a

	for guard in 80:
		_add_pixel(point, seen)
		if point == b:
			break
		var doubled: int = 2 * error
		if doubled >= dy:
			error += dy
			point.x += step_x
		if doubled <= dx:
			error += dx
			point.y += step_y


func _add_pixel(point: Vector2i, seen: Dictionary) -> void:
	# Everything stays inside the circle (rounding to whole pixels could poke out a little).
	if seen.has(point) or Vector2(point).length() > radius:
		return
	seen[point] = true
	_pixels.append({"pos": point, "dist": Vector2(point).length(), "edge": false})

	# A lighter pixel next to some crack pixels gives the crack a bit of depth.
	var edge_point := Vector2i(point.x + 1, point.y)
	if randf() < 0.2 and not seen.has(edge_point) and Vector2(edge_point).length() <= radius:
		seen[edge_point] = true
		_pixels.append({"pos": edge_point, "dist": Vector2(edge_point).length(), "edge": true})


func _process(delta: float) -> void:
	_age += delta
	if _age > lifetime + fade_time:
		queue_free()
		return
	# Redraw only while something changes (spreading and fading).
	if _age < pop_time + 0.05 or _age > lifetime:
		queue_redraw()


func _draw() -> void:
	var spread: float = clampf(_age / pop_time, 0.0, 1.0) * (radius + 1.0)
	var alpha: float = 1.0
	if _age > lifetime:
		alpha = clampf(1.0 - (_age - lifetime) / fade_time, 0.0, 1.0)

	for pixel in _pixels:
		if float(pixel["dist"]) > spread:
			continue
		var color: Color = EDGE_COLOR if pixel["edge"] else CRACK_COLOR
		color.a *= alpha
		draw_rect(Rect2(Vector2(pixel["pos"]), Vector2.ONE), color)
