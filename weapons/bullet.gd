extends Area2D
class_name PlayerBullet
## A rifle bullet. Flies straight; hits the first enemy (take_hit) or wall and sparks.
## The collision shape (bullet.tscn) is a 20 x 4 px rectangle along the flight direction: twice the
## original size, easier to hit with, and longer than the ~7 px the bullet travels per physics frame,
## so it can't skip through enemies.

@export var enemy_spark_color: Color = Color(1.0, 0.35, 0.3)
@export var wall_spark_color: Color = Color(1.0, 0.85, 0.4)

var _velocity: Vector2 = Vector2.ZERO
var _damage: float = 0.0
var _knockback: float = 0.0
var _lifetime_left: float = 1.0
var _source_id: int = 0
var _weapon_class: WeaponClass.Type = WeaponClass.Type.LIGHT
var _spent: bool = false


## Creates the bullet in the current scene (deferred, safe in physics callbacks).
static func launch(
	scene: PackedScene, tree: SceneTree, from: Vector2, direction: Vector2,
	speed: float, damage: float, knockback: float, lifetime: float, source: Node2D,
	weapon_class: WeaponClass.Type = WeaponClass.Type.LIGHT
) -> PlayerBullet:
	if scene == null or tree == null or tree.current_scene == null:
		return null

	var bullet := scene.instantiate() as PlayerBullet
	if bullet == null:
		return null

	var dir: Vector2 = direction.normalized()
	bullet._velocity = dir * speed
	bullet._damage = damage
	bullet._knockback = knockback
	bullet._lifetime_left = lifetime
	bullet._source_id = source.get_instance_id() if source != null else 0
	bullet._weapon_class = weapon_class
	bullet.rotation = dir.angle()

	var container: Node = tree.current_scene
	var container_2d := container as Node2D
	bullet.position = container_2d.to_local(from) if container_2d != null else from
	container.add_child.call_deferred(bullet)
	return bullet


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _spent:
		return

	global_position += _velocity * delta

	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _spent or body.is_in_group("player"):
		return

	var direction: Vector2 = _velocity.normalized()

	if body.is_in_group("npc") and body.has_method("take_hit"):
		var shooter := instance_from_id(_source_id) as Node2D  # null if gone
		body.take_hit(HitInfo.create(_damage, shooter, direction, _knockback, true, _weapon_class))
		Fx.impact(get_tree(), global_position, -direction, enemy_spark_color)
		_expire()
	elif body is StaticBody2D:
		# World walls and houses.
		Fx.impact(get_tree(), global_position, -direction, wall_spark_color)
		_expire()


func _expire() -> void:
	_spent = true
	set_deferred("monitoring", false)
	queue_free()
