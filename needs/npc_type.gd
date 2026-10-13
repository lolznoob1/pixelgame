extends RefCounted
class_name NpcType
## The size class of a character. It decides how fast the hunger runs down.

enum Type { LIGHT, MEDIUM, HEAVY, SPECIAL, PLAYER }

## Hunger units lost per minute.
const HUNGER_PER_MINUTE: Dictionary = {
	Type.LIGHT: 2.0,
	Type.MEDIUM: 3.0,
	Type.HEAVY: 4.0,
	Type.SPECIAL: 0.0,
	Type.PLAYER: 20.0,
}


## For NPCs the rate doubles with every step of rarity (common x1, uncommon x2, rare x4, legendary x8, mythical x16).
static func hunger_per_minute(type: Type, rarity_tier: int = 0) -> float:
	var base: float = float(HUNGER_PER_MINUTE.get(type, 0.0))
	if type == Type.PLAYER:
		return base
	return base * pow(2.0, float(maxi(rarity_tier, 0)))


static func display_name(type: Type) -> String:
	return String(Type.keys()[type]).capitalize()
