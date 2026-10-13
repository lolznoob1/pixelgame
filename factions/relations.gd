extends RefCounted
class_name Relations
## All relations of the game, in one place (static, like DevSettings).
##
##  - The PLAYER has faction points (-100..100) with every faction. They change through actions, each action
##    has a weight (ActionWeight): hitting a peaceful NPC is HOSTILE (-5), killing it is EVIL (-10), and so on.
##  - UNIQUE NPCs have their own points with the player, one by one. They are neutral to every faction and
##    to each other, and only the player can change their relation.
##  - FACTIONS have a fixed relation to each other (the tables below, edit them to taste).
##  - The wave event sets `event_all_hostile`: every non-unique NPC is hostile to the player while it runs.

## Pairs of factions that fight each other / that get along. Everything else is neutral.
## A faction is friendly to itself.
const HOSTILE_PAIRS: Array = [
	[Faction.Id.POLICE, Faction.Id.GANG1], [Faction.Id.POLICE, Faction.Id.GANG2], [Faction.Id.POLICE, Faction.Id.GANG3],
	[Faction.Id.POLICE, Faction.Id.CULT], [Faction.Id.POLICE, Faction.Id.DEMON], [Faction.Id.POLICE, Faction.Id.ALIEN],
	[Faction.Id.GANG1, Faction.Id.GANG2], [Faction.Id.GANG1, Faction.Id.GANG3], [Faction.Id.GANG2, Faction.Id.GANG3],
	[Faction.Id.MILITARY, Faction.Id.ALIEN], [Faction.Id.MILITARY, Faction.Id.DEMON],
	[Faction.Id.HOLY, Faction.Id.DEMON], [Faction.Id.HOLY, Faction.Id.CULT],
	[Faction.Id.CHURCH, Faction.Id.DEMON], [Faction.Id.CHURCH, Faction.Id.CULT],
	[Faction.Id.ALIEN, Faction.Id.CIVILIAN],
]
const FRIENDLY_PAIRS: Array = [
	[Faction.Id.POLICE, Faction.Id.EMERGENCY], [Faction.Id.POLICE, Faction.Id.CIVILIAN], [Faction.Id.POLICE, Faction.Id.MILITARY],
	[Faction.Id.EMERGENCY, Faction.Id.CIVILIAN], [Faction.Id.CHURCH, Faction.Id.HOLY], [Faction.Id.CHURCH, Faction.Id.CIVILIAN],
	[Faction.Id.CULT, Faction.Id.DEMON],
]
## Starting points of the player with each faction (missing = 0).
const START_POINTS: Dictionary = {}

static var player_points: Dictionary = {}   # Faction.Id -> int
static var unique_points: Dictionary = {}   # unique_id (StringName) -> int
## true while the wave event runs: all non-unique NPCs are hostile to the player.
static var event_all_hostile: bool = false
## Increases with every change, so UIs can notice that something changed.
static var version: int = 0

static var _pairs: Dictionary = {}


## A new game: forget everything the player did.
static func reset() -> void:
	player_points.clear()
	unique_points.clear()
	event_all_hostile = false
	version += 1


# --------------------------------------------------
# PLAYER <-> FACTIONS
# --------------------------------------------------

static func faction_points(faction: Faction.Id) -> int:
	return int(player_points.get(faction, START_POINTS.get(faction, 0)))


static func set_faction_points(faction: Faction.Id, points: int) -> void:
	if faction == Faction.Id.UNIQUE:
		return
	player_points[faction] = clampi(points, Relation.MIN_POINTS, Relation.MAX_POINTS)
	version += 1


static func add_faction_points(faction: Faction.Id, points: int) -> void:
	set_faction_points(faction, faction_points(faction) + points)


## An action of the player with a weight (see ActionWeight) toward a faction.
static func apply_action(faction: Faction.Id, weight: ActionWeight.Type, scale: float = 1.0) -> void:
	add_faction_points(faction, roundi(float(ActionWeight.points(weight)) * scale))


static func faction_to_player(faction: Faction.Id) -> Relation.Level:
	return Relation.from_points(faction_points(faction))


# --------------------------------------------------
# UNIQUE NPCS (individual relations with the player)
# --------------------------------------------------

static func unique_points_of(unique_id: StringName) -> int:
	return int(unique_points.get(unique_id, 0))


static func set_unique_points(unique_id: StringName, points: int) -> void:
	unique_points[unique_id] = clampi(points, Relation.MIN_POINTS, Relation.MAX_POINTS)
	version += 1


static func add_unique_points(unique_id: StringName, points: int) -> void:
	set_unique_points(unique_id, unique_points_of(unique_id) + points)


static func apply_unique_action(unique_id: StringName, weight: ActionWeight.Type, scale: float = 1.0) -> void:
	add_unique_points(unique_id, roundi(float(ActionWeight.points(weight)) * scale))


# --------------------------------------------------
# NPCS (anything with `faction` and `unique_id`)
# --------------------------------------------------

static func unique_id_of(npc: Node) -> StringName:
	var value: Variant = npc.get("unique_id")
	return StringName(value) if value != null else &""


static func faction_of(npc: Node) -> Faction.Id:
	if unique_id_of(npc) != &"":
		return Faction.Id.UNIQUE
	var value: Variant = npc.get("faction")
	return value if value != null else Faction.Id.CIVILIAN


static func is_unique(npc: Node) -> bool:
	return unique_id_of(npc) != &""


## How this NPC stands to the player.
static func npc_to_player(npc: Node) -> Relation.Level:
	var unique_id: StringName = unique_id_of(npc)
	if unique_id != &"":
		return Relation.from_points(unique_points_of(unique_id))  # individual: the event does not change it
	if event_all_hostile:
		return Relation.Level.HOSTILE
	return faction_to_player(faction_of(npc))


## How two NPCs (or the player and an NPC) stand to each other.
static func between(a: Node, b: Node) -> Relation.Level:
	if a.is_in_group("player"):
		return npc_to_player(b)
	if b.is_in_group("player"):
		return npc_to_player(a)
	# Unique NPCs are always neutral to every faction (and to each other).
	if is_unique(a) or is_unique(b):
		return Relation.Level.NEUTRAL
	return faction_to_faction(faction_of(a), faction_of(b))


static func faction_to_faction(a: Faction.Id, b: Faction.Id) -> Relation.Level:
	if a == Faction.Id.UNIQUE or b == Faction.Id.UNIQUE:
		return Relation.Level.NEUTRAL
	if a == b:
		return Relation.Level.FRIENDLY
	_ensure_pairs()
	return _pairs.get(_pair_key(a, b), Relation.Level.NEUTRAL)


static func is_hostile(a: Node, b: Node) -> bool:
	return between(a, b) == Relation.Level.HOSTILE


static func is_friendly(a: Node, b: Node) -> bool:
	return between(a, b) == Relation.Level.FRIENDLY


# --------------------------------------------------
# WHAT THE PLAYER DOES TO NPCS
# --------------------------------------------------

## Changes the player's standing with this NPC's faction (or with this unique NPC alone).
static func apply_to_npc(npc: Node, weight: ActionWeight.Type) -> void:
	var unique_id: StringName = unique_id_of(npc)
	if unique_id != &"":
		apply_unique_action(unique_id, weight)
	else:
		apply_action(faction_of(npc), weight)


static func _pair_key(a: Faction.Id, b: Faction.Id) -> int:
	return mini(a, b) * 100 + maxi(a, b)


static func _ensure_pairs() -> void:
	if not _pairs.is_empty():
		return
	for pair in FRIENDLY_PAIRS:
		_pairs[_pair_key(pair[0], pair[1])] = Relation.Level.FRIENDLY
	for pair in HOSTILE_PAIRS:
		_pairs[_pair_key(pair[0], pair[1])] = Relation.Level.HOSTILE
