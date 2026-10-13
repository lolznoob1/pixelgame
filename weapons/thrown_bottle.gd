extends Area2D
class_name ThrownBottle
## A glass bottle of water thrown with the right mouse button. It flies to the target point
## (or until it hits something), shatters, and leaves water on the ground (WaterSplash).
## Hit detection: Area2D overlap with the first enemy body (take_hit) or wall/house.

## Flight speed in pixels per second.
const SPEED: float = 230.0

@export var spin_speed: float = 16.0
## Visual only: how high the bottle is lifted at the top of its arc.
@export var arc_height: float = 12.0

@onready var sprite: Sprite2D = $Sprite2D

var _start: Vector2 = Vector2.ZERO
var _target: Vector2 = Vector2.ZERO
var _flight_time: float = 0.3
var _age: float = 0.0
var _damage: float = 0.0
var _knockback: float = 0.0
var _source_id: int = 0
var _spent: bool = false


## Creates the bottle in the current scene. `from` and `target` are global positions.
## The scene is passed in (instead of preloaded here) to avoid a cyclic preload.
static func launch(
	scene: PackedScene, tree: SceneTree, from: Vector2, target: Vector2,
	damage: float, knockback: float, source: Node2D
) -> ThrownBottle:
	if scene == null or tree == null or tree.current_scene == null:
		return null

	var bottle := scene.instantiate() as ThrownBottle
	if bottle == null:
		return null

	bottle._start = from
	bottle._target = target
	bottle._flight_time = maxf(from.distance_to(target) / SPEED, 0.08)
	bottle._damage = damage
	bottle._knockback = knockback
	bottle._source_id = source.get_instance_id() if source != null else 0

	var container: Node = tree.current_scene
	var container_2d := container as Node2D
	bottle.position = container_2d.to_local(from) if container_2d != null else from
	container.add_child.call_deferred(bottle)
	return bottle


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _spent:
		return

	_age += delta
	var progress: float = clampf(_age / _flight_time, 0.0, 1.0)

	global_position = _start.lerp(_target, progress)
	sprite.position.y = -sin(progress * PI) * arc_height  # fake height
	sprite.rotation += spin_speed * delta
	queue_redraw()

	if progress >= 1.0:
		_shatter()  # landed on the ground


func _draw() -> void:
	# Flat shadow on the ground.
	draw_set_transform(Vector2(0.0, 1.0), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 4.0, Color(0.0, 0.0, 0.0, 0.3))


func _on_body_entered(body: Node2D) -> void:
	if _spent or body.is_in_group("player"):
		return

	if body.is_in_group("npc") and body.has_method("take_hit"):
		var thrower := instance_from_id(_source_id) as Node2D  # null if gone
		var direction: Vector2 = (_target - _start).normalized()
		body.take_hit(HitInfo.create(_damage, thrower, direction, _knockback))
		_shatter()
	elif body is StaticBody2D:
		_shatter()  # walls and houses


func _shatter() -> void:
	if _spent:
		return
	_spent = true
	set_deferred("monitoring", false)

	Fx.glass_shatter(get_tree(), global_position)
	WaterSplash.spawn(get_tree(), global_position)
	queue_free()
