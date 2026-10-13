extends RefCounted
class_name FactionInventories
## Every faction has ONE inventory that all its members share. They can only reach it at a specific place: a
## FactionStorage object on the map (where those objects are is not decided yet).

static var _inventories: Dictionary = {}  # Faction.Id -> Inventory


static func of(faction: Faction.Id) -> Inventory:
	if not _inventories.has(faction):
		_inventories[faction] = Inventory.new()
	return _inventories[faction] as Inventory


static func reset() -> void:
	_inventories.clear()
