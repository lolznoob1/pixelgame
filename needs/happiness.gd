extends RefCounted
class_name Happiness
## The mood of a character.
##   NPCs:   by the goals they have not reached (see NpcGoal): 0 = happy, 1-2 = unrest, 3-4 = unhappy, 5+ = depressed.
##   Player: by the drink value: 80-100 = happy, 50-79 = unrest, 10-49 = unhappy, 0-9 = depressed.

enum State { HAPPY, UNREST, UNHAPPY, DEPRESSED }

## Movement speed of the PLAYER in each mood (unrest changes nothing).
const SPEED_MODIFIER: Dictionary = {
	State.HAPPY: 1.2,
	State.UNREST: 1.0,
	State.UNHAPPY: 0.9,
	State.DEPRESSED: 0.6,
}


static func from_unfulfilled_goals(unfulfilled: int) -> State:
	if unfulfilled <= 0:
		return State.HAPPY
	if unfulfilled <= 2:
		return State.UNREST
	if unfulfilled <= 4:
		return State.UNHAPPY
	return State.DEPRESSED


static func from_drink(value: float) -> State:
	if value >= 80.0:
		return State.HAPPY
	if value >= 50.0:
		return State.UNREST
	if value >= 10.0:
		return State.UNHAPPY
	return State.DEPRESSED


static func speed_modifier(state: State) -> float:
	return float(SPEED_MODIFIER.get(state, 1.0))


static func display_name(state: State) -> String:
	return String(State.keys()[state]).capitalize()
