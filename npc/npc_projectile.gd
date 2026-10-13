extends Area2D
class_name NpcProjectile
## A thrown object (the shoe). Flies straight, hits the player once, then vanishes.
## Hit detection: Area2D overlap with the player's body -> player.take_hit(HitInfo).

@export var spin_speed: float = 14.0

@onready var sprite: Sprite2D = $Sprite2D

var _velocity: Vector2 = Vector2.ZERO
var _damage: float = 0.0
var _knockback: float = 0.0
var _stun: bool = true
var _lifetime_left: float = 2.0
# Stored as an id: the thrower may be dead by the time the shoe lands.
var _source_id: int = 0
var _spent: bool = false


## Creates the projectile and adds it to the current scene (deferred, so this is
## safe to call from physics callbacks). `from` is in global coordinates.
static func launch(
	scene: PackedScene,
	tree: SceneTree,
	from: Vector2,
	direction: Vector2,
	speed: float,
	damage: float,
	knockback: float,
	lifetime: float,
	source: Node2D,
	stun: bool = true
) -> NpcProjectile:
	if scene == null or tree == null or tree.current_scene == null:
		return null

	var projectile := scene.instantiate() as NpcProjectile
	if projectile == null:
		return null

	projectile._velocity = direction.normalized() * speed
	projectile._damage = damage
	projectile._knockback = knockback
	projectile._stun = stun
	projectile._lifetime_left = lifetime
	projectile._source_id = source.get_instance_id() if source != null else 0

	var container: Node = tree.current_scene
	var container_2d := container as Node2D
	projectile.position = container_2d.to_local(from) if container_2d != null else from
	container.add_child.call_deferred(projectile)
	return projectile


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	sprite.rotation = randf() * TAU


func _physics_process(delta: float) -> void:
	if _spent:
		return

	global_position += _velocity * delta
	sprite.rotation += spin_speed * delta

	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _spent:
		return

	if body.is_in_group("player") or body.is_in_group("npc"):
		var thrower := instance_from_id(_source_id) as Node2D  # null if already freed
		if body == thrower:
			return
		# It hits whoever the thrower is hostile to, or the one it aimed at (the thrower's target).
		var aimed_at: Variant = thrower.get("target") if thrower != null else null
		if thrower != null and aimed_at != body and not Relations.is_hostile(thrower, body):
			return
		if body.has_method("take_hit"):
			body.take_hit(HitInfo.create(_damage, thrower, _velocity.normalized(), _knockback, _stun))
		_expire()
	elif body is StaticBody2D:
		_expire()  # world walls


func _expire() -> void:
	_spent = true
	set_deferred("monitoring", false)
	queue_free()
