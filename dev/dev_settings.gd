extends RefCounted
class_name DevSettings
## Live balance settings, edited in the pause menu (ESC > Developer).
## Everything lives in static variables, so changes apply immediately and also survive a restart of
## the scene (not of the game). The spawner's inspector values are the defaults.

## Pickups that get an individual chance slider: [item id, display name].
const PICKUP_ITEMS: Array = [
	[&"health_pack", "Health Pack"],
	[&"stamina_drink", "Stamina Drink"],
	[&"speed_boost", "Speed Boost"],
	[&"damage_boost", "Damage Boost"],
	[&"shield", "Shield"],
	[&"ak47", "AK-47"],
	[&"rocket_launcher", "Rocket Launcher"],
	[&"ability_core", "Ability Core"],
]

static var initialized: bool = false

# --- Display ---
static var show_rarity_labels: bool = true
## The colored light under enemies.
static var show_rarity_glow: bool = true
## The faction name above NPCs (green friendly, gray neutral, red hostile).
static var show_faction_labels: bool = true

# --- Player (defaults come from the player's exports) ---
static var player_initialized: bool = false
## Health / stamina regained per second (upgrades add to these).
static var health_regen: float = 2.0
static var stamina_regen: float = 10.0

# --- Enemy spawner (relative weights, normalized when an enemy is picked) ---
static var enemy1_chance: float = 0.333
static var enemy2_chance: float = 0.328
static var enemy3_chance: float = 0.339
static var first_wave_enemies: int = 10
static var first_wave_variants: int = 1
## Counts are multiplied by this every wave (2 = doubling).
static var wave_growth: float = 2.0
static var waves_per_cycle: int = 5
static var reset_count_each_cycle: bool = true
static var wave_duration: float = 30.0
static var spawn_spread_seconds: float = 20.0
static var max_enemies: int = 500

# --- Rarity ---
## When on, every normal enemy rolls extra ranks on top of the wave rank.
static var random_rarity: bool = false
## Weights for +0, +1, +2, +3, +4 extra ranks.
static var rarity_weights: Array[float] = [60.0, 25.0, 10.0, 4.0, 1.0]

# --- Drops (multipliers on top of the drop tables) ---
static var coin_chance_mult: float = 1.0
static var coin_amount_mult: float = 1.0
static var pickup_chance_mult: float = 1.0
static var pickup_amount_mult: float = 1.0
## Per pickup type: item id -> chance multiplier.
static var item_chance_mult: Dictionary = {}


## Takes the player's regeneration exports as the defaults (first start only).
static func init_from_player(player: Node) -> void:
	health_regen = player.get("health_regen_rate")
	stamina_regen = player.get("stamina_regen_rate")
	player_initialized = true


## Takes the spawner's inspector values as the defaults (first start only).
static func init_from_spawner(spawner: Node) -> void:
	_reset_values()

	var chance2: float = spawner.get("enemy2_chance")
	var chance3: float = spawner.get("enemy3_chance")
	enemy2_chance = chance2
	enemy3_chance = chance3
	enemy1_chance = maxf(1.0 - chance2 - chance3, 0.0)

	first_wave_enemies = spawner.get("first_wave_enemies")
	first_wave_variants = spawner.get("first_wave_variants")
	waves_per_cycle = spawner.get("waves_per_cycle")
	reset_count_each_cycle = spawner.get("reset_count_each_cycle")
	wave_duration = spawner.get("wave_duration")
	spawn_spread_seconds = spawner.get("spawn_spread_seconds")
	max_enemies = spawner.get("max_enemies")
	initialized = true


## Back to the inspector values / factory settings.
static func reset_to_defaults(spawner: Node, player: Node = null) -> void:
	if spawner != null:
		init_from_spawner(spawner)
	else:
		_reset_values()

	if player != null:
		init_from_player(player)


static func _reset_values() -> void:
	show_rarity_labels = true
	show_faction_labels = true
	show_rarity_glow = true
	wave_growth = 2.0
	random_rarity = false
	rarity_weights = [60.0, 25.0, 10.0, 4.0, 1.0]
	coin_chance_mult = 1.0
	coin_amount_mult = 1.0
	pickup_chance_mult = 1.0
	pickup_amount_mult = 1.0
	item_chance_mult = {}


## Multiplier for the drop chance of an item (coins vs. pickups, plus the per-item slider).
static func drop_chance_multiplier(item: ItemData) -> float:
	if item.effect == ItemData.Effect.COIN:
		return coin_chance_mult
	return pickup_chance_mult * float(item_chance_mult.get(item.id, 1.0))


static func drop_amount_multiplier(item: ItemData) -> float:
	return coin_amount_mult if item.effect == ItemData.Effect.COIN else pickup_amount_mult
