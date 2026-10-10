# attack_behavior.gd
extends EnemyBehavior
class_name AttackBehavior

@export var attack_cooldown: float = 1.0

var cooldown_timer := 0.0

func enter(enemy: EnemyCharacter) -> void:
	cooldown_timer = 0.0
	enemy.desired_speed = 0.0

func update(enemy: EnemyCharacter, delta: float) -> void:
	enemy.desired_speed = 0.0
	cooldown_timer -= delta

	var target: Node2D = enemy.target
	if target == null or not is_instance_valid(target):
		return

	if cooldown_timer <= 0.0:
		enemy.perform_attack(target)
		cooldown_timer = attack_cooldown

func exit(enemy: EnemyCharacter) -> void:
	enemy.desired_speed = 0.0
