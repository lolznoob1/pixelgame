extends Node2D
class_name ScorchMark
## Soot left on the ground by an explosion: dark pixels scattered at random in a circle,
## denser in the middle (same idea as WaterSplash and GroundCracks). Spreads out, stays, fades.

@export var radius: float = 40.0
@export var lifetime: float = 10.0
@export var fade_time: float = 4.0
@export var pop_time: float = 0.15

var _spots: Array[Dictionary] = []  # {"pos": Vector2, "size": float, "color": Color, "dist": float}
var _age: float = 0.0


static func spawn(tree: SceneTree, global_pos: Vector2, scorch_radius: float) -> void:
	var scene: Node = tree.current_scene if tree != null else null
	if scene == null:
		return

	var mark := ScorchMark.new()
	mark.radius = scorch_radius
	mark.z_index = -5  # above the background (z -10), below characters (z 0)

	var scene_2d := scene as Node2D
	mark.position = scene_2d.to_local(global_pos) if scene_2d != null else global_pos
	scene.add_child.call_deferred(mark)


func _ready() -> void:
	var count: int = int(radius * radius * 0.07)
	for i in count:
		var angle: float = randf() * TAU
		# Uniform over the disc, pulled toward the middle.
		var distance: float = radius * sqrt(randf()) * randf_range(0.55, 1.0)
		var pos := Vector2(roundf(cos(angle) * distance), roundf(sin(angle) * distance))
		var near_center: bool = distance < radius * 0.4

		var tone: float = randf_range(0.05, 0.18)
		var color := Color(tone, tone * 0.9, tone * 0.95, randf_range(0.5, 0.85))
		if near_center and randf() < 0.08:
			color = Color(0.6, 0.18, 0.08, 0.7)  # a few embers in the middle

		_spots.append({
			"pos": pos,
			"size": 2.0 if (near_center and randf() < 0.5) else 1.0,
			"color": color,
			"dist": distance,
		})


func _process(delta: float) -> void:
	_age += delta
	if _age > lifetime + fade_time:
		queue_free()
		return
	if _age < pop_time + 0.05 or _age > lifetime:
		queue_redraw()


func _draw() -> void:
	var spread: float = clampf(_age / pop_time, 0.0, 1.0) * radius
	var alpha: float = 1.0
	if _age > lifetime:
		alpha = clampf(1.0 - (_age - lifetime) / fade_time, 0.0, 1.0)

	for spot in _spots:
		if float(spot["dist"]) > spread:
			continue
		var color: Color = spot["color"]
		color.a *= alpha
		var size: float = spot["size"]
		draw_rect(Rect2(spot["pos"], Vector2(size, size)), color)
