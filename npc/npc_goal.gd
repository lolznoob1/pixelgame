extends Resource
class_name NpcGoal
## One condition an NPC has to fulfill to be happy. An NPC has a set of them (NpcStats.goals):
##   all fulfilled      -> happy
##   1 or 2 unfulfilled -> unrest
##   3 or 4 unfulfilled -> unhappy
##   5 or more          -> depressed
## (see Happiness.from_unfulfilled_goals). The mood changes how aggressive the NPC is (unhappy: notices enemies from
## farther away, depressed: hardly reacts) and whether it shares food.

enum Condition {
	HUNGER_ABOVE,       ## hunger value is at least `value` (0-100)
	HAS_FOOD,           ## carries at least `value` food items
	HAS_COINS,          ## carries at least `value` coins
	HEALTH_ABOVE,       ## health is at least `value` of the maximum (0-1)
	NO_HOSTILE_NEARBY,  ## no enemy within `value` pixels
	FRIENDLY_NEARBY,    ## a friend within `value` pixels (company)
	NEAR_HOME,          ## within `value` pixels of the place where it lives
}

@export var condition: Condition = Condition.HUNGER_ABOVE
## The number belonging to the condition (see the comments above).
@export var value: float = 50.0


static func make(goal_condition: Condition, goal_value: float) -> NpcGoal:
	var goal := NpcGoal.new()
	goal.condition = goal_condition
	goal.value = goal_value
	return goal


## The goals of an NPC whose stats don't define any: fed, has food, has money, healthy, safe, has company.
static func default_set() -> Array[NpcGoal]:
	var goals: Array[NpcGoal] = []
	goals.append(make(Condition.HUNGER_ABOVE, 50.0))
	goals.append(make(Condition.HAS_FOOD, 1.0))
	goals.append(make(Condition.HAS_COINS, 3.0))
	goals.append(make(Condition.HEALTH_ABOVE, 0.6))
	goals.append(make(Condition.NO_HOSTILE_NEARBY, 150.0))
	goals.append(make(Condition.FRIENDLY_NEARBY, 120.0))
	return goals


func is_fulfilled(npc: NpcCharacter) -> bool:
	match condition:
		Condition.HUNGER_ABOVE:
			return npc.hunger.value >= value
		Condition.HAS_FOOD:
			return npc.food_count() >= int(value)
		Condition.HAS_COINS:
			return npc.inventory.count(&"coin") >= int(value)
		Condition.HEALTH_ABOVE:
			return npc.health >= npc.max_health * value
		Condition.NO_HOSTILE_NEARBY:
			return not npc.has_nearby(value, Relation.Level.HOSTILE)
		Condition.FRIENDLY_NEARBY:
			return npc.has_nearby(value, Relation.Level.FRIENDLY)
		Condition.NEAR_HOME:
			return npc.global_position.distance_to(npc.home_position) <= value
	return true
