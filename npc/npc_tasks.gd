extends RefCounted
class_name NpcTasks
## What NPCs do when they have a need. For now: find food. Anything that can feed an NPC (a store entrance, the
## storage of the NPC's own faction) is in the group "food_source" and implements
##   can_serve_food(npc) -> bool,  serve_food(npc) -> bool,  food_spot() -> Vector2.

const GROUP: StringName = &"food_source"
const MAX_DISTANCE: float = 2500.0


## The nearest food source that can serve this NPC right now (null if there is none).
static func find_food_source(npc: NpcCharacter) -> Node2D:
	var best: Node2D = null
	var best_distance: float = MAX_DISTANCE * MAX_DISTANCE
	for node in npc.get_tree().get_nodes_in_group(GROUP):
		var source := node as Node2D
		if source == null or not source.has_method("can_serve_food") or not source.call("can_serve_food", npc):
			continue
		var distance: float = npc.global_position.distance_squared_to(source.global_position)
		if distance < best_distance:
			best_distance = distance
			best = source
	return best
