extends RefCounted
class_name Relation
## How one party stands to another. Faction points run from -100 to 100:
##   friendly  at FRIENDLY_FROM or more,  hostile  at HOSTILE_UNTIL or less,  neutral in between.
## (My choice of thresholds, change them here.)

enum Level { HOSTILE, NEUTRAL, FRIENDLY }

const MIN_POINTS: int = -100
const MAX_POINTS: int = 100
const FRIENDLY_FROM: int = 25
const HOSTILE_UNTIL: int = -25


static func from_points(points: int) -> Level:
	if points >= FRIENDLY_FROM:
		return Level.FRIENDLY
	if points <= HOSTILE_UNTIL:
		return Level.HOSTILE
	return Level.NEUTRAL


static func display_name(level: Level) -> String:
	match level:
		Level.FRIENDLY:
			return "Friendly"
		Level.HOSTILE:
			return "Hostile"
	return "Neutral"
