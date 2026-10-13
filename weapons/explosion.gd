extends RefCounted
class_name Explosion
## Explosion damage with two radii (center to center). Everything inside the first radius takes
## `damage`; everything inside the second radius takes `damage * outer_fraction` ON TOP of that.
## With 500 / 50 px and 80 px / half damage: inside 50 px an enemy takes 500 + 250 = 750,
## between 50 and 80 px it takes 250. Enemy armor applies to the total. The player is not hurt.


static func detonate(
	tree: SceneTree, center: Vector2, damage: float, inner_radius: float, outer_radius: float,
	outer_fraction: float, knockback: float, source: Node2D,
	weapon_class: WeaponClass.Type = WeaponClass.Type.HEAVY
) -> void:
	Fx.explosion(tree, center, inner_radius, outer_radius)

	var victims: Array[Node2D] = HitDetection.targets_in_arc(
		tree, &"npc", center, Vector2.RIGHT, maxf(inner_radius, outer_radius), 360.0
	)
	for enemy in victims:
		if not enemy.has_method("take_hit"):
			continue

		var distance: float = center.distance_to(enemy.global_position)
		var total: float = 0.0
		if distance <= inner_radius:
			total += damage
		if distance <= outer_radius:
			total += damage * outer_fraction
		if total <= 0.0:
			continue

		var direction: Vector2 = (enemy.global_position - center).normalized()
		if direction.is_zero_approx():
			direction = Vector2.from_angle(randf() * TAU)
		enemy.take_hit(HitInfo.create(total, source, direction, knockback, true, weapon_class))
