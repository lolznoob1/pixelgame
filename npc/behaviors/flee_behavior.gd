extends NpcBehavior
class_name FleeBehavior

@export var speed: float = 70.0
@export_range(0.0, 45.0) var wobble_degrees: float = 0.0

var _wobble_offset: float = 0.0

func enter(_enemy: NpcCharacter) -> void:
	_wobble_offset = deg_to_rad(randf_range(-wobble_degrees, wobble_degrees))

func update(enemy: NpcCharacter, _delta: float) -> void:
	var target: Node2D = enemy.target

	if target == null or not is_instance_valid(target):
		enemy.desired_speed = 0.0
		return

	var away: Vector2 = target.global_position.direction_to(
		enemy.global_position
	)

	if away == Vector2.ZERO:
		away = Vector2.from_angle(randf() * TAU)

	enemy.desired_direction = away.rotated(_wobble_offset)
	enemy.desired_speed = speed

func exit(_enemy: NpcCharacter) -> void:
	pass
