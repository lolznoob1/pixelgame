extends Resource
class_name DropEntry
## One line of a DropTable.

@export var item: ItemData
## Chance (0..1) that this entry drops at all.
@export_range(0.0, 1.0) var chance: float = 1.0
@export var min_count: int = 1
@export var max_count: int = 1
## If true the items are TAKEN from the dropping entity's inventory (e.g. the player
## loses coins when hit) instead of appearing from nowhere. Each pickup = 1 unit,
## so use items with amount = 1 for this.
@export var from_inventory: bool = false
