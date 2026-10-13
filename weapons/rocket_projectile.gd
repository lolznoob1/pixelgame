extends Area2D
class_name RocketProjectile
## A rocket: flies straight with an animated flame and a smoke trail, and explodes when it hits
## an enemy, a wall or a house, or at the end of its range. The damage is dealt by Explosion.

const SHEET: Texture2D = preload("res://assets/weapons/rocket_frames.png")
const FRAME_WIDTH: int = 14
const FRAME_HEIGHT: int = 7
const FRAME_COUNT: int = 3

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _velocity: Vector2 = Vector2.ZERO
var _lifetime_left: float = 1.6
var _damage: float = 0.0
var _inner_radius: float = 50.0
var _outer_radius: float = 80.0
var _outer_fraction: float = 0.5
var _knockback: float = 0.0
var _source_id: int = 0
var _weapon_class: WeaponClass.Type = WeaponClass.Type.HEAVY
var _spent: bool = false


## Creates the rocket in the current scene (deferred, safe in physics callbacks).
static func launch(
	scene: PackedScene, tree: SceneTree, from: Vector2, direction: Vector2,
	speed: float, lifetime: float, damage: float, inner_radius: float, outer_radius: float,
	outer_fraction: float, knockback: float, source: Node2D,
	weapon_class: WeaponClass.Type = WeaponClass.Type.HEAVY
) -> RocketProjectile:
	if scene == null or tree == null or tree.current_scene == null:
		return null

	var rocket := scene.instantiate() as RocketProjectile
	if rocket == null:
		return null

	var dir: Vector2 = direction.normalized()
	rocket._velocity = dir * speed
	rocket._lifetime_left = lifetime
	rocket._damage = damage
	rocket._inner_radius = inner_radius
	rocket._outer_radius = outer_radius
	rocket._outer_fraction = outer_fraction
	rocket._knockback = knockback
	rocket._source_id = source.get_instance_id() if source != null else 0
	rocket._weapon_class = weapon_class
	rocket.rotation = dir.angle()

	var container: Node = tree.current_scene
	var container_2d := container as Node2D
	rocket.position = container_2d.to_local(from) if container_2d != null else from
	container.add_child.call_deferred(rocket)
	return rocket


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build_flame_animation()
	_add_smoke_trail()


# The strip has 3 flame frames; they flicker while flying.
func _build_flame_animation() -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 14.0)
	frames.set_animation_loop(&"default", true)
	for i in FRAME_COUNT:
		var atlas := AtlasTexture.new()
		atlas.atlas = SHEET
		atlas.region = Rect2(i * FRAME_WIDTH, 0, FRAME_WIDTH, FRAME_HEIGHT)
		frames.add_frame(&"default", atlas)
	sprite.sprite_frames = frames
	sprite.play(&"default")


# Grey smoke left behind in the world (local_coords off), so it stays where the rocket was.
func _add_smoke_trail() -> void:
	var smoke := CPUParticles2D.new()
	smoke.local_coords = false
	smoke.amount = 18
	smoke.lifetime = 0.5
	smoke.position = Vector2(-6.0, 0.0)
	smoke.direction = Vector2.LEFT
	smoke.spread = 14.0
	smoke.initial_velocity_min = 12.0
	smoke.initial_velocity_max = 30.0
	smoke.gravity = Vector2.ZERO
	smoke.scale_amount_min = 1.5
	smoke.scale_amount_max = 3.2

	var fade := Gradient.new()
	fade.set_color(0, Color(0.8, 0.78, 0.76, 0.85))
	fade.set_color(1, Color(0.4, 0.38, 0.38, 0.0))
	smoke.color_ramp = fade

	smoke.emitting = true
	add_child(smoke)


func _physics_process(delta: float) -> void:
	if _spent:
		return

	global_position += _velocity * delta

	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		_explode()  # out of range: it blows up in the air


func _on_body_entered(body: Node2D) -> void:
	if _spent or body.is_in_group("player"):
		return

	if body.is_in_group("npc") or body is StaticBody2D:  # enemies, world walls, houses
		_explode()


func _explode() -> void:
	if _spent:
		return
	_spent = true
	set_deferred("monitoring", false)

	var shooter := instance_from_id(_source_id) as Node2D  # null if gone
	Explosion.detonate(
		get_tree(), global_position, _damage, _inner_radius, _outer_radius, _outer_fraction, _knockback, shooter, _weapon_class
	)
	queue_free()
