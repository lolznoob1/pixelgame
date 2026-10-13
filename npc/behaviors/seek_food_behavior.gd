# seek_food_behavior.gd
extends NpcBehavior
class_name SeekFoodBehavior
## A hungry NPC without food walks to the nearest food source (a store, its faction's storage) and gets some there.
## Gives up after `give_up_time` seconds or when nothing can serve it (then it waits a while before trying again).

@export var speed: float = 40.0
## How close it has to get to use the source.
@export var use_radius: float = 22.0
@export var give_up_time: float = 45.0

var _source: Node2D
var _time_left: float = 0.0


func enter(npc: NpcCharacter) -> void:
	_source = NpcTasks.find_food_source(npc)
	_time_left = give_up_time
	if _source == null:
		npc.task_failed()


func update(npc: NpcCharacter, delta: float) -> void:
	_time_left -= delta
	if not is_instance_valid(_source) or _time_left <= 0.0:
		npc.task_failed()
		return

	var spot: Vector2 = _source.call("food_spot")
	var to_spot: Vector2 = spot - npc.global_position
	if to_spot.length() <= use_radius:
		if _source.call("serve_food", npc):
			npc.task_done()
		else:
			npc.task_failed()
		return

	npc.desired_direction = to_spot.normalized()
	npc.desired_speed = speed


func exit(npc: NpcCharacter) -> void:
	npc.desired_speed = 0.0
	_source = null
