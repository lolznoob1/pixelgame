extends RefCounted
class_name ItemEconomy
## The values of items that can change while the game runs: prices and how much a need item restores.
## Everything reads from here (stores, NPCs), so one call changes it everywhere:
##
##   ItemEconomy.set_price(&"sandwich", 3)              one item
##   ItemEconomy.set_restore(&"beer", 30.0)             how much thirst a beer restores
##   ItemEconomy.category_price_multiplier[ItemData.Category.NEED] = 1.5    all need items 50 % more expensive
##   ItemEconomy.global_price_multiplier = 2.0          everything twice as expensive (an event, inflation ...)
##
## "Need" items (ItemData.Category.NEED) are food and drinks.

static var price_overrides: Dictionary = {}     # item id -> int
static var restore_overrides: Dictionary = {}   # item id -> float
static var category_price_multiplier: Dictionary = {}  # ItemData.Category -> float
static var global_price_multiplier: float = 1.0


static func price_of(item: ItemData) -> int:
	var base: int = int(price_overrides.get(item.id, item.base_price))
	var multiplier: float = global_price_multiplier * float(category_price_multiplier.get(item.category, 1.0))
	return maxi(0, roundi(float(base) * multiplier))


static func set_price(item_id: StringName, price: int) -> void:
	price_overrides[item_id] = maxi(0, price)


## How much of the need an item restores (the hunger of a sandwich, the thirst of a beer).
static func restore_of(item: ItemData) -> float:
	return float(restore_overrides.get(item.id, item.amount))


static func set_restore(item_id: StringName, amount: float) -> void:
	restore_overrides[item_id] = maxf(0.0, amount)


static func is_need(item: ItemData) -> bool:
	return item != null and item.category == ItemData.Category.NEED


static func reset() -> void:
	price_overrides.clear()
	restore_overrides.clear()
	category_price_multiplier.clear()
	global_price_multiplier = 1.0
