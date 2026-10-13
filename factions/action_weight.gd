extends RefCounted
class_name ActionWeight
## How good or bad an action is. The weight decides how many faction points the action is worth.

enum Type { ANGELIC, HOLY, GOOD, NICE, SOMEWHAT_GOOD, NEUTRAL, RUDE, HOSTILE, EVIL, DEMONIC }

const POINTS: Dictionary = {
	Type.ANGELIC: 20,
	Type.HOLY: 10,
	Type.GOOD: 5,
	Type.NICE: 2,
	Type.SOMEWHAT_GOOD: 1,
	Type.NEUTRAL: 0,
	Type.RUDE: -1,
	Type.HOSTILE: -5,
	Type.EVIL: -10,
	Type.DEMONIC: -50,
}


static func points(type: Type) -> int:
	return int(POINTS.get(type, 0))
