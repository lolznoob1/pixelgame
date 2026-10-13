# chase_behavior.gd
extends NpcBehavior
class_name ChaseBehavior

@export var speed: float = 50.0
## Once the enemy is inside the encirclement ring it heads for the target;
## this adds extra pull toward the target against the separation push.
@export var player_approach_weight: float = 0.35


func update(enemy: NpcCharacter, _delta: float) -> void:
	var target: Node2D = enemy.target

	if not is_instance_valid(target):
		enemy.desired_speed = 0.0
		return

	var ai: NpcAI = enemy.ai
	var to_target: Vector2 = enemy.global_position.direction_to(target.global_position)
	var direction: Vector2

	if ai.is_slot_active():
		# Walk to this enemy's assigned spot on the ring around the target.
		var to_slot: Vector2 = ai.get_approach_point(enemy) - enemy.global_position
		direction = to_slot.normalized()
	else:
		# Inside the ring (or encirclement off): close in on the target.
		direction = to_target * (1.0 + player_approach_weight)

	# Keep some distance to the neighbours.
	direction += ai.get_separation() * ai.separation_strength

	if direction.length_squared() > 0.001:
		enemy.desired_direction = direction.normalized()
	else:
		enemy.desired_direction = to_target

	enemy.desired_speed = speed
