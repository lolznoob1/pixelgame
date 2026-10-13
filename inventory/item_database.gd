extends RefCounted
class_name ItemDatabase
## Finds an ItemData by its id (inventories only store ids). New items: create the .tres and add it to PATHS.

const PATHS: Array[String] = [
	"res://items/data/coin.tres",
	"res://items/data/health_pack.tres",
	"res://items/data/stamina_drink.tres",
	"res://items/data/speed_boost.tres",
	"res://items/data/damage_boost.tres",
	"res://items/data/shield.tres",
	"res://items/data/ak47.tres",
	"res://items/data/rocket_launcher.tres",
	"res://items/data/ability_core.tres",
	"res://items/data/sandwich.tres",
	"res://items/data/beer.tres",
]

static var _items: Dictionary = {}  # StringName -> ItemData


static func get_item(item_id: StringName) -> ItemData:
	_ensure_loaded()
	return _items.get(item_id) as ItemData


static func all_items() -> Array[ItemData]:
	_ensure_loaded()
	var result: Array[ItemData] = []
	for item in _items.values():
		result.append(item as ItemData)
	return result


## The first item that has this effect (e.g. food for hunger), or null.
static func first_with_effect(effect: ItemData.Effect) -> ItemData:
	for item in all_items():
		if item.effect == effect:
			return item
	return null


static func _ensure_loaded() -> void:
	if not _items.is_empty():
		return
	for path in PATHS:
		var item := load(path) as ItemData
		if item != null:
			_items[item.id] = item
