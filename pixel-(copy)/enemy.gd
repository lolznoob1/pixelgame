
extends CharacterBody2D

@export var speed: float = 50.0
@export var max_health: float = 100.0
@export var knockback_speed: float = 500.0
@export var knockback_immunity_duration: float = 2.0
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var collision_immunity_id: int = 0
var original_collision_layer: int
var original_collision_mask: int
var collision_immunity_active: bool = false
var health: float
var hurt: bool = false
var dead: bool = false
var player: Node2D
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_distance_remaining: float = 0.0


func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	original_collision_layer = collision_layer
	original_collision_mask = collision_mask

	player = get_tree().get_first_node_in_group("player") as Node2D
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("idle")
func apply_knockback(
	direction: Vector2,
	distance: float = 160.0
	
) -> void:
	if direction.is_zero_approx() or dead:
		return

	knockback_velocity = direction.normalized() * knockback_speed
	knockback_distance_remaining = distance

	# Disable collision immediately after being hit
	if not collision_immunity_active:
		collision_immunity_active = true
		collision_layer = 0
		collision_mask = 0

	# Restart the 2-second immunity timer
	restore_collision_after_delay()

	knockback_velocity = direction.normalized() * knockback_speed
	knockback_distance_remaining = distance

func restore_collision_after_delay() -> void:
	collision_immunity_id += 1
	var my_id: int = collision_immunity_id

	await get_tree().create_timer(
		knockback_immunity_duration
	).timeout

	# Ignore outdated timers
	if my_id != collision_immunity_id:
		return

	collision_layer = original_collision_layer
	collision_mask = original_collision_mask
	collision_immunity_active = false


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
		velocity = Vector2.ZERO
		return

	if knockback_distance_remaining > 0.0:
		var frame_distance: float = minf(
			knockback_speed * delta,
			knockback_distance_remaining
		)

		velocity = knockback_velocity.normalized() * knockback_speed
		velocity = velocity.normalized() * (frame_distance / delta)

		var previous_position: Vector2 = global_position
		move_and_slide()

		var actual_distance: float = previous_position.distance_to(
			global_position
		)

		knockback_distance_remaining -= actual_distance

		if is_zero_approx(actual_distance) or knockback_distance_remaining <= 0.0:
			knockback_distance_remaining = 0.0
			knockback_velocity = Vector2.ZERO

		return

	var direction: Vector2 = global_position.direction_to(
		player.global_position
	)

	var current_speed: float = speed

	if hurt:
		current_speed *= 0.5

	velocity = direction * current_speed

	if direction.x != 0:
		sprite.flip_h = direction.x < 0

	move_and_slide()



	# Do not override hurt animation
	if hurt:
		return

	if velocity.length() > 0:
		play_animation("walk")
	else:
		play_animation("idle")
		
func play_animation(anim_name: String) -> void:
	if sprite.animation != anim_name:
		sprite.play(anim_name)


func take_damage(amount: float) -> void:
	if amount <= 0.0 or dead:
		return

	health = maxf(health - amount, 0.0)

	if health <= 0.0:
		die()
	else:
		hurt = true
		sprite.play("hurt")


func die() -> void:
	if dead:
		return

	dead = true
	hurt = false
	knockback_distance_remaining = 0.0
	knockback_velocity = Vector2.ZERO
	velocity = Vector2.ZERO

	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		sprite.animation_finished.connect(
			func():
				queue_free(),
			CONNECT_ONE_SHOT
		)
	else:
		queue_free()



func _on_animation_finished() -> void:
	match sprite.animation:
		"hurt":
			hurt = false
		"death":
			queue_free()

	# Keep your existing enemy movement AI here.
	# For example, follow the player and call move_and_slide().

	var direction: Vector2 = global_position.direction_to(
		player.global_position
	)

	velocity = direction * speed
	move_and_slide()
