# ranged_attack_behavior.gd
extends AttackBehavior
class_name RangedAttackBehavior
## Attack state for ranged enemies: instead of pressing into the target it keeps
## a distance band around it and throws something (see NpcCharacter projectile).
##   closer than min_distance  -> back away
##   farther than max_distance -> step closer
##   in between               -> stand still and attack

@export var min_distance: float = 30.0
@export var max_distance: float = 80.0
## Speed while correcting the distance. Keep it BELOW the player's speed (40 in main.tscn),
## otherwise the player can never catch up with a retreating thrower.
@export var adjust_speed: float = 30.0


func update(enemy: NpcCharacter, delta: float) -> void:
	var target: Node2D = enemy.target
	if not is_instance_valid(target):
		enemy.desired_speed = 0.0
		return

	var to_target: Vector2 = target.global_position - enemy.global_position
	var distance: float = to_target.length()
	var direction: Vector2 = to_target.normalized()

	# Always look at the target, even while walking backwards.
	enemy.look_direction = direction

	if distance < min_distance:
		enemy.desired_direction = -direction
		enemy.desired_speed = adjust_speed
	elif distance > max_distance:
		enemy.desired_direction = direction
		enemy.desired_speed = adjust_speed
	else:
		enemy.desired_direction = direction
		enemy.desired_speed = 0.0

	cooldown_timer -= delta
	if cooldown_timer <= 0.0:
		enemy.perform_attack(target)
		cooldown_timer = attack_cooldown
