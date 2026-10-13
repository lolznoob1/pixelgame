# attack_behavior.gd
extends NpcBehavior
class_name AttackBehavior

@export var attack_cooldown: float = 1.0
## While in attack range the enemy keeps pressing toward the target at this
## speed. Without it the enemy would stop short of its touch hitbox and never
## actually touch the player (contact is what hurts).
@export var press_in_speed: float = 20.0

var cooldown_timer: float = 0.0


func enter(enemy: NpcCharacter) -> void:
	# cooldown_timer is NOT reset here, so re-entering the state
	# quickly can't be used to skip the cooldown.
	enemy.desired_speed = 0.0


func update(enemy: NpcCharacter, delta: float) -> void:
	var target: Node2D = enemy.target
	if not is_instance_valid(target):
		enemy.desired_speed = 0.0
		return

	enemy.desired_direction = enemy.global_position.direction_to(target.global_position)
	enemy.desired_speed = press_in_speed

	cooldown_timer -= delta
	if cooldown_timer <= 0.0:
		enemy.perform_attack(target)
		cooldown_timer = attack_cooldown


func exit(enemy: NpcCharacter) -> void:
	enemy.desired_speed = 0.0
