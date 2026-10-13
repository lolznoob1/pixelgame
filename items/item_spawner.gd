extends RefCounted
class_name ItemSpawner
## Creates ItemPickup nodes in the world.

const PICKUP_SCENE: PackedScene = preload("res://items/item_pickup.tscn")
## Hard cap so thousands of kills can't leave thousands of pickups behind.
const MAX_PICKUPS: int = 150


static func spawn(
	item: ItemData,
	origin: Vector2,
	tree: SceneTree,
	scatter_distance: float = 24.0
) -> ItemPickup:
	if item == null or tree == null or tree.current_scene == null:
		return null

	if tree.get_nodes_in_group("pickup").size() >= MAX_PICKUPS:
		return null

	var pickup := PICKUP_SCENE.instantiate() as ItemPickup
	if pickup == null:
		return null

	var container: Node = tree.current_scene
	var landing: Vector2 = origin
	for attempt in range(8):
		var candidate: Vector2 = origin + Vector2.from_angle(randf() * TAU) * randf_range(scatter_distance * 0.4, scatter_distance)
		if not HouseColliders.point_blocked(tree, candidate):
			landing = candidate
			break

	pickup.item = item
	pickup.launch_target = landing

	var container_2d := container as Node2D
	pickup.position = container_2d.to_local(origin) if container_2d != null else origin

	# Deferred: drops usually happen inside physics callbacks, where adding
	# collision objects directly is not allowed.
	container.add_child.call_deferred(pickup)
	return pickup
