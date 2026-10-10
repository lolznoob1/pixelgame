# wander_behavior.gd
extends EnemyBehavior
class_name WanderBehavior

@export var speed: float = 40.0
@export var change_direction_time: float = 2.0

var direction := Vector2.ZERO
var timer := 0.0

func enter(_enemy: EnemyCharacter) -> void:
	timer = 0.0

func update(enemy: EnemyCharacter, delta: float) -> void:
	timer -= delta

	if timer <= 0.0:
		direction = Vector2.RIGHT.rotated(randf_range(-PI, PI))
		timer = change_direction_time

	enemy.desired_direction = direction
	enemy.desired_speed = speed

func exit(_enemy: EnemyCharacter) -> void:
	pass
