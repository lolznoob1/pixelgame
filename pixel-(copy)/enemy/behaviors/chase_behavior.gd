
# chase_behavior.gd
extends EnemyBehavior
class_name ChaseBehavior

@export var speed: float = 50.0
@export var slot_arrival_distance: float = 12.0
@export var player_approach_weight: float = 0.35

func enter(_enemy: EnemyCharacter) -> void:
	pass


func update(enemy: EnemyCharacter, _delta: float) -> void:
	var target: Node2D = enemy.target

	if target == null or not is_instance_valid(target):
		enemy.desired_speed = 0.0
		return

	var ai := enemy.get_node_or_null("EnemyAI") as EnemyAI

	# Fall back to normal chasing if encirclement is unavailable.
	if ai == null or not ai.encircle_enabled:
		enemy.desired_direction = enemy.global_position.direction_to(
			target.global_position
		)
		enemy.desired_speed = speed
		return

	var slot_position: Vector2 = ai.get_encircle_target()
	var to_slot := slot_position - enemy.global_position
	var player_direction := enemy.global_position.direction_to(
		target.global_position
	)

	var approach_direction: Vector2

	if to_slot.length() > slot_arrival_distance:
		# Move toward this enemy's assigned position around the player.
		approach_direction = to_slot.normalized()
	else:
		# Once positioned, continue closing in on the player.
		approach_direction = player_direction

	var separation := ai.get_separation_direction(enemy)

	# Combine slot-seeking, player pursuit, and enemy separation.
	var direction := approach_direction

	if to_slot.length() <= slot_arrival_distance:
		direction = (
			approach_direction
			+ player_direction * player_approach_weight
		)

	direction += separation * ai.separation_strength

	if direction.length_squared() > 0.001:
		enemy.desired_direction = direction.normalized()
	else:
		enemy.desired_direction = player_direction

	enemy.desired_speed = speed


func exit(_enemy: EnemyCharacter) -> void:
	pass
