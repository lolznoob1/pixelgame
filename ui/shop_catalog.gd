extends RefCounted
class_name ShopCatalog
## What the shop can sell: weapons and the health pack. At the start of each wave four random
## entries (repeats are possible) are offered. To sell something new, add it to ENTRIES.

const ENTRIES: Array[Dictionary] = [
	{"path": "res://items/data/ak47.tres", "price": 5},
	{"path": "res://items/data/health_pack.tres", "price": 2},
	{"path": "res://items/data/rocket_launcher.tres", "price": 8},
]


## Prices double with every enemy rank-up: x1, x2, x4, x8, x16.
static func price_multiplier(rank: int) -> int:
	return 1 << clampi(rank, 0, 4)


## `count` random offers: [{"item": ItemData, "price": base price, "sold": false}, ...]
static func roll_offers(count: int) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	for i in count:
		var entry: Dictionary = ENTRIES[randi() % ENTRIES.size()]
		var item := load(entry["path"]) as ItemData
		if item == null:
			push_warning("ShopCatalog: could not load %s" % entry["path"])
			continue
		offers.append({"item": item, "price": int(entry["price"]), "sold": false})
	return offers
