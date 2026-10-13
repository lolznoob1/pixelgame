extends Resource
class_name DropTable
## A list of DropEntry plus the rules for rolling them. Used for the enemies' death drops (one table per
## rarity, see RarityDrops) and anywhere else something should drop items.
##
## Mode INDEPENDENT: every entry is rolled on its own (chance, then a random count between min and max).
## Mode SINGLE_CHOICE: exactly ONE outcome is picked, using the entries' chances as weights, plus
##   `no_drop_weight` for "nothing drops". The weights should add up to 1 together.
## `max_items` limits the total number of pickups. If the roll gives more, the surplus is removed at random,
## but never below an entry's own minimum (so a guaranteed "10 coins" stays 10 coins).

enum Mode { INDEPENDENT, SINGLE_CHOICE }

@export var mode: Mode = Mode.INDEPENDENT
## SINGLE_CHOICE only: the weight of "nothing drops".
@export_range(0.0, 1.0) var no_drop_weight: float = 0.0
## Most pickups this table may drop in total (0 = no limit).
@export var max_items: int = 0

# Array[Resource] instead of Array[DropEntry] keeps the hand-editable .tres files simple;
# anything that is not a DropEntry is skipped with a warning.
@export var entries: Array[Resource] = []


## Rolls the table and returns one ItemData per pickup that should spawn.
## `source` is the dropping entity (needed for from_inventory entries).
func roll(source: Node = null) -> Array[ItemData]:
	var groups: Array[Dictionary] = []  # {"item": ItemData, "count": int, "min": int}

	if mode == Mode.SINGLE_CHOICE:
		_roll_single_choice(groups, source)
	else:
		_roll_independent(groups, source)

	_apply_limit(groups)

	var result: Array[ItemData] = []
	for group in groups:
		for i in int(group["count"]):
			result.append(group["item"])
	return result


func _roll_independent(groups: Array[Dictionary], source: Node) -> void:
	for resource in entries:
		var entry := _valid_entry(resource)
		if entry == null:
			continue

		# Developer multipliers (pause menu) apply to normal drops, not to items taken from an inventory.
		var chance: float = entry.chance
		if not entry.from_inventory:
			chance = clampf(chance * DevSettings.drop_chance_multiplier(entry.item), 0.0, 1.0)
		if randf() > chance:
			continue

		_add_group(groups, entry, source)


func _roll_single_choice(groups: Array[Dictionary], source: Node) -> void:
	var weights: Array[float] = []
	var total: float = no_drop_weight
	for resource in entries:
		var entry := _valid_entry(resource)
		var weight: float = 0.0
		if entry != null:
			weight = entry.chance
			if not entry.from_inventory:
				weight *= DevSettings.drop_chance_multiplier(entry.item)
		weights.append(weight)
		total += weight

	if total <= 0.0:
		return

	var pick: float = randf() * total
	var accumulated: float = 0.0
	for i in entries.size():
		accumulated += weights[i]
		if pick < accumulated:
			_add_group(groups, _valid_entry(entries[i]), source)
			return
	# otherwise: the "nothing drops" part of the roll


func _valid_entry(resource: Resource) -> DropEntry:
	var entry := resource as DropEntry
	if entry == null or entry.item == null:
		push_warning("DropTable: skipped an entry that is not a valid DropEntry with an item.")
		return null
	return entry


# Rolls the count of one entry (min..max, developer amount multiplier) and adds it as a group.
func _add_group(groups: Array[Dictionary], entry: DropEntry, source: Node) -> void:
	if entry == null:
		return

	var minimum: int = mini(entry.min_count, entry.max_count)
	var count: int = randi_range(minimum, maxi(entry.min_count, entry.max_count))

	if not entry.from_inventory:
		var amount_multiplier: float = DevSettings.drop_amount_multiplier(entry.item)
		if amount_multiplier != 1.0:
			# Fractions are rolled: 1.4 x of 1 item = 1, plus a 40 % chance of a second one.
			var scaled: float = float(count) * amount_multiplier
			count = floori(scaled) + (1 if randf() < scaled - floorf(scaled) else 0)
	if count <= 0:
		return

	if entry.from_inventory:
		if source == null or not source.has_method("take_from_inventory"):
			return
		count = source.take_from_inventory(entry.item.id, count)
		if count <= 0:
			return

	groups.append({"item": entry.item, "count": count, "min": mini(minimum, count)})


# Enforces max_items: first remove extras above the entries' minimums (at random). Only if the minimums
# alone are too many, coins are removed first (the cheapest thing to lose), then anything else.
func _apply_limit(groups: Array[Dictionary]) -> void:
	if max_items <= 0:
		return

	var total: int = 0
	for group in groups:
		total += int(group["count"])

	while total > max_items:
		var removable: Array[int] = []
		for i in groups.size():
			if int(groups[i]["count"]) > int(groups[i]["min"]):
				removable.append(i)
		if removable.is_empty():
			break
		var pick: int = removable[randi() % removable.size()]
		groups[pick]["count"] = int(groups[pick]["count"]) - 1
		total -= 1

	while total > max_items:
		var candidates: Array[int] = []
		for i in groups.size():
			var is_coin: bool = (groups[i]["item"] as ItemData).effect == ItemData.Effect.COIN
			if int(groups[i]["count"]) > 0 and is_coin:
				candidates.append(i)
		if candidates.is_empty():
			for i in groups.size():
				if int(groups[i]["count"]) > 0:
					candidates.append(i)
		if candidates.is_empty():
			break
		var pick: int = candidates[randi() % candidates.size()]
		groups[pick]["count"] = int(groups[pick]["count"]) - 1
		total -= 1
