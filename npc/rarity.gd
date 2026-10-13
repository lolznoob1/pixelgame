extends RefCounted
class_name Rarity
## Enemy rarity. Every step up DOUBLES health, armor and attack damage:
## common x1, uncommon x2, rare x4, legendary x8, mythical x16.

enum Tier { COMMON, UNCOMMON, RARE, LEGENDARY, MYTHICAL }

const NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Legendary", "Mythical"]

const COLORS: Array[Color] = [
	Color(0.85, 0.85, 0.85),  # common
	Color(0.40, 0.90, 0.40),  # uncommon
	Color(0.35, 0.60, 1.00),  # rare
	Color(1.00, 0.65, 0.15),  # legendary
	Color(0.85, 0.40, 1.00),  # mythical
]


static func clamp_tier(tier: int) -> int:
	return clampi(tier, Tier.COMMON, Tier.MYTHICAL)


static func multiplier(tier: int) -> float:
	return pow(2.0, float(clamp_tier(tier)))


static func display_name(tier: int) -> String:
	return NAMES[clamp_tier(tier)]


static func color(tier: int) -> Color:
	return COLORS[clamp_tier(tier)]


## Subtle sprite tint so rarities are recognizable without reading the label.
static func sprite_tint(tier: int) -> Color:
	return Color.WHITE.lerp(color(tier), 0.5)
