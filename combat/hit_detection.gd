extends RefCounted
class_name HitDetection
## Shared hit detection for player AND enemy attacks.
##
## An attack hits a target when the target's center is
##   1. within `reach` pixels of the attacker, and
##   2. inside the attack arc: the angle between the facing direction and the
##      direction to the target is at most arc_degrees / 2.
## arc_degrees = 180 is a half circle in front of the attacker, 360 a full circle.


static func is_in_arc(
	origin: Vector2,
	facing: Vector2,
	point: Vector2,
	reach: float,
	arc_degrees: float
) -> bool:
	var offset: Vector2 = point - origin
	var distance_squared: float = offset.length_squared()

	if distance_squared > reach * reach:
		return false

	# Standing on top of the attacker, or a full circle: always a hit.
	if arc_degrees >= 359.9 or distance_squared < 0.0001 or facing.is_zero_approx():
		return true

	var half_arc: float = deg_to_rad(arc_degrees) * 0.5
	return absf(facing.angle_to(offset)) <= half_arc


## All nodes of `group` that are inside the arc.
static func targets_in_arc(
	tree: SceneTree,
	group: StringName,
	origin: Vector2,
	facing: Vector2,
	reach: float,
	arc_degrees: float
) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for node in tree.get_nodes_in_group(group):
		var target := node as Node2D
		if target == null:
			continue
		if is_in_arc(origin, facing, target.global_position, reach, arc_degrees):
			result.append(target)
	return result
