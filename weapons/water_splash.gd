extends Node2D
class_name WaterSplash
## Water left on the ground after a bottle shatters: a handful of single pixels in a random
## pattern inside a small circle, a few bigger ones in the middle. They pop outward, stay for a
## few seconds and fade away.

const COLORS: Array[Color] = [
	Color(0.35, 0.65, 0.95, 0.85),
	Color(0.50, 0.78, 1.00, 0.80),
	Color(0.25, 0.50, 0.90, 0.85),
	Color(0.70, 0.88, 1.00, 0.70),
]

## Radius of the circle the pixels are scattered in.
@export var radius: float = 15.0
@export var min_pixels: int = 11
@export var max_pixels: int = 17
## Seconds the water stays before it starts to fade.
@export var lifetime: float = 5.0
@export var fade_time: float = 1.5

var _drops: Array[Dictionary] = []
var _age: float = 0.0


## Creates a splash in the current scene at a global position.
static func spawn(tree: SceneTree, global_pos: Vector2, splash_radius: float = 15.0) -> void:
	var scene: Node = tree.current_scene if tree != null else null
	if scene == null:
		return

	var splash := WaterSplash.new()
	splash.radius = splash_radius
	splash.z_index = -5  # above the background (z -10), below characters (z 0)

	var scene_2d := scene as Node2D
	splash.position = scene_2d.to_local(global_pos) if scene_2d != null else global_pos
	scene.add_child.call_deferred(splash)


func _ready() -> void:
	_generate()


# Random pattern: uniformly distributed over the disc, snapped to whole pixels.
func _generate() -> void:
	for i in randi_range(min_pixels, max_pixels):
		var angle: float = randf() * TAU
		var distance: float = sqrt(randf()) * radius
		_drops.append({
			"pos": Vector2(roundf(cos(angle) * distance), roundf(sin(angle) * distance)),
			"size": 1.0 if randf() < 0.7 else 2.0,
			"color": COLORS[randi() % COLORS.size()],
		})

	# A tiny puddle where the bottle burst.
	for i in randi_range(2, 4):
		_drops.append({
			"pos": Vector2(roundf(randf_range(-2.0, 2.0)), roundf(randf_range(-2.0, 2.0))),
			"size": 2.0,
			"color": COLORS[0],
		})


func _process(delta: float) -> void:
	_age += delta
	if _age > lifetime + fade_time:
		queue_free()
		return
	# Redraw only while something changes (pop-out and fade).
	if _age < 0.2 or _age > lifetime:
		queue_redraw()


func _draw() -> void:
	var pop: float = clampf(_age / 0.12, 0.0, 1.0)  # droplets fly out from the middle
	var alpha: float = 1.0
	if _age > lifetime:
		alpha = clampf(1.0 - (_age - lifetime) / fade_time, 0.0, 1.0)

	for drop in _drops:
		var color: Color = drop["color"]
		color.a *= alpha
		var size: float = drop["size"]
		var pos: Vector2 = ((drop["pos"] as Vector2) * pop).round()
		draw_rect(Rect2(pos, Vector2(size, size)), color)
