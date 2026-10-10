extends CharacterBody2D
class_name EnemyCharacter

signal attack_requested(target: Node2D)
signal died

## Optional. If assigned, its values override the exports below.
## If empty, the enemy uses the exports, so existing scenes keep working.
@export var stats: EnemyStats

@export_group("Stats")
@export var max_health: float = 100.0
@export var detection_range: float = 700.0
@export var attack_range: float = 30.0
@export_range(0.0, 1.0) var flee_health_ratio: float = 0.25
@export var hurt_speed_multiplier: float = 0.5

@export_group("Knockback")
@export var knockback_speed: float = 500.0
@export var knockback_immunity_duration: float = 2.0

@onready var ai: EnemyAI = $EnemyAI
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Set by the AI behaviors, applied in _physics_process.
var desired_direction := Vector2.ZERO
var desired_speed := 0.0

var health: float
var target: Node2D
var hurt: bool = false
var dead: bool = false

# Filled from EnemyStats in _ready() (defaults match the old behavior).
var contact_damage: float = 1.0
var speed_multiplier: float = 1.0
var knockback_resistance: float = 0.0
var idle_anim: StringName = &"idle"
var walk_anim: StringName = &"walk"
var hurt_anim: StringName = &"hurt"
var death_anim: StringName = &"death"

var _knockback_direction := Vector2.ZERO
var _knockback_distance_remaining: float = 0.0

var _original_collision_layer: int
var _original_collision_mask: int
var _collision_immunity_active: bool = false
var _collision_immunity_id: int = 0


func _ready() -> void:
	add_to_group("enemy")
	_apply_stats()
	health = max_health

	_original_collision_layer = collision_layer
	_original_collision_mask = collision_mask

	sprite.animation_finished.connect(_on_animation_finished)
	_play_animation(idle_anim)


func _apply_stats() -> void:
	if stats == null:
		return

	max_health = stats.max_health
	contact_damage = stats.contact_damage
	speed_multiplier = stats.speed_multiplier
	knockback_resistance = stats.knockback_resistance

	idle_anim = stats.idle_animation
	walk_anim = stats.walk_animation
	hurt_anim = stats.hurt_animation
	death_anim = stats.death_animation

	if stats.sprite_frames != null:
		sprite.sprite_frames = stats.sprite_frames
	# Multiply, so a scale already set in the scene is kept when stats use 1,1.
	sprite.scale *= stats.sprite_scale


func _physics_process(delta: float) -> void:
	if dead:
		return

	# Knockback overrides the AI completely while it lasts.
	if _process_knockback(delta):
		return

	ai.update_ai(self, delta)

	var speed: float = desired_speed * speed_multiplier
	if hurt:
		speed *= hurt_speed_multiplier

	velocity = desired_direction * speed
	move_and_slide()

	_update_visuals()


# --------------------------------------------------
# COMBAT
# --------------------------------------------------

func perform_attack(target_node: Node2D) -> void:
	# Connect this signal to your combat/damage system.
	attack_requested.emit(target_node)


func take_damage(amount: float) -> void:
	if amount <= 0.0 or dead:
		return

	health = maxf(health - amount, 0.0)

	if health <= 0.0:
		_die()
	elif sprite.sprite_frames.has_animation(hurt_anim):
		# Only enter the hurt state if there is an animation to end it,
		# otherwise "hurt" would never be cleared.
		hurt = true
		sprite.play(hurt_anim)


func _die() -> void:
	dead = true
	hurt = false
	_knockback_distance_remaining = 0.0
	velocity = Vector2.ZERO
	died.emit()

	if sprite.sprite_frames.has_animation(death_anim):
		sprite.play(death_anim)  # queue_free() happens in _on_animation_finished
	else:
		queue_free()


# --------------------------------------------------
# KNOCKBACK
# --------------------------------------------------

func apply_knockback(direction: Vector2, distance: float = 160.0) -> void:
	if direction.is_zero_approx() or dead:
		return

	_knockback_direction = direction.normalized()
	_knockback_distance_remaining = distance * (1.0 - knockback_resistance)

	# Disable collision immediately after being hit.
	if not _collision_immunity_active:
		_collision_immunity_active = true
		collision_layer = 0
		collision_mask = 0

	_restore_collision_after_delay()


# Returns true while knockback is active.
func _process_knockback(delta: float) -> bool:
	if _knockback_distance_remaining <= 0.0:
		return false

	var step: float = minf(
		knockback_speed * delta,
		_knockback_distance_remaining
	)

	velocity = _knockback_direction * (step / delta)

	var previous_position: Vector2 = global_position
	move_and_slide()
	var moved: float = previous_position.distance_to(global_position)

	_knockback_distance_remaining -= moved

	if is_zero_approx(moved):
		_knockback_distance_remaining = 0.0

	return true


func _restore_collision_after_delay() -> void:
	_collision_immunity_id += 1
	var my_id: int = _collision_immunity_id

	await get_tree().create_timer(knockback_immunity_duration).timeout

	# Ignore outdated timers.
	if my_id != _collision_immunity_id:
		return

	collision_layer = _original_collision_layer
	collision_mask = _original_collision_mask
	_collision_immunity_active = false


# --------------------------------------------------
# VISUALS
# --------------------------------------------------

func _update_visuals() -> void:
	if desired_direction.x != 0.0:
		sprite.flip_h = desired_direction.x < 0.0

	# Do not override the hurt animation.
	if hurt:
		return

	_play_animation(walk_anim if velocity.length() > 0.0 else idle_anim)


func _play_animation(anim_name: StringName) -> void:
	# Skip missing animations instead of erroring.
	if not sprite.sprite_frames.has_animation(anim_name):
		return
	if sprite.animation != anim_name:
		sprite.play(anim_name)


func _on_animation_finished() -> void:
	if sprite.animation == hurt_anim:
		hurt = false
	elif sprite.animation == death_anim:
		queue_free()
