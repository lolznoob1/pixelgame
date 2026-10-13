extends RefCounted
class_name Inventory
## A bag of items: item id -> amount. Used by the player, by NPCs, by stores and by the factions
## (every faction has one shared inventory, see FactionInventories).

signal changed

var items: Dictionary = {}  # StringName -> int


func count(item_id: StringName) -> int:
	return int(items.get(item_id, 0))


func has(item_id: StringName, amount: int = 1) -> bool:
	return count(item_id) >= amount


## Adds items and returns how many were added.
func add(item_id: StringName, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	items[item_id] = count(item_id) + amount
	changed.emit()
	return amount


## Removes up to `amount` items and returns how many were really removed.
func remove(item_id: StringName, amount: int = 1) -> int:
	var removed: int = mini(amount, count(item_id))
	if removed <= 0:
		return 0
	var left: int = count(item_id) - removed
	if left > 0:
		items[item_id] = left
	else:
		items.erase(item_id)
	changed.emit()
	return removed


## Moves up to `amount` of an item into another inventory. Returns how many were moved.
func transfer_to(other: Inventory, item_id: StringName, amount: int = 1) -> int:
	var moved: int = remove(item_id, amount)
	if moved > 0:
		other.add(item_id, moved)
	return moved


func total() -> int:
	var sum: int = 0
	for amount in items.values():
		sum += int(amount)
	return sum


func is_empty() -> bool:
	return items.is_empty()


func ids() -> Array:
	return items.keys()


func clear() -> void:
	items.clear()
	changed.emit()
