extends GameEvent
class_name WaveEvent
## THE WAVE EVENT (the old wave system). It is OFF until start() is called (developer menu > Events), and when it
## runs it:
##   - makes every non-unique NPC hostile to the player (Relations.event_all_hostile),
##   - spawns waves of hostile NPCs around the player and scales the difficulty over time,
##   - shows the hourglass (WaveHud), which only exists while the event is active,
##   - lets its NPCs drop by their rarity (RarityDrops); normal NPCs drop what they carry.
## When it ends, its NPCs disappear and everything is back to normal.

# --------------------------------------------------
# ENEMY SCENES
# --------------------------------------------------

@export var enemy_scene: PackedScene = preload("res://npc/scenes/npc_basic.tscn")
@export var enemy2_scene: PackedScene = preload("res://npc/scenes/npc_woman.tscn")
@export var enemy3_scene: PackedScene = preload("res://npc/scenes/npc_speeder.tscn")

@export var enemy_container: Node2D
@export var no_spawn_tiles: TileMapLayer
@export var Background: Sprite2D


# --------------------------------------------------
# SPAWN DISTANCE
# --------------------------------------------------

@export_group("Spawn Distance")
@export var min_spawn_distance: float = 400.0
@export var max_spawn_distance: float = 600.0

@export_group("Player Protection")
@export var safe_radius: float = 350.0


# --------------------------------------------------
# MOVEMENT-BASED SPAWNING
# --------------------------------------------------

@export_group("Movement-Based Spawning")

# Aim the spawn formation in the direction the player is moving.
@export var follow_player_movement: bool = true

# Total width of the spawn arc in degrees: 180 = half-circle, 360 = full circle.
@export_range(0.0, 360.0) var spawn_arc_degrees: float = 180.0

# Ignore tiny movements to avoid jitter.
@export var movement_deadzone: float = 10.0

var last_movement_direction: Vector2 = Vector2.RIGHT


# --------------------------------------------------
# WAVES
# --------------------------------------------------

@export_group("Waves")
## Seconds per wave. The next wave (level) starts when the time is up.
@export var wave_duration: float = 30.0
## Enemies of wave 1 (at the base rarity).
@export var first_wave_enemies: int = 10
## Extra "variant" enemies of wave 1, spawned at `variant_rarity` in addition to the normal ones.
@export var first_wave_variants: int = 1
@export var variant_rarity: Rarity.Tier = Rarity.Tier.RARE
## Counts double every wave. After this many waves everything ranks up one rarity.
@export var waves_per_cycle: int = 5
## true: the doubling starts over (10, 20, 40, 80, 160) after every rank-up.
## false: the count keeps doubling forever (gets huge very quickly!).
@export var reset_count_each_cycle: bool = true
## A wave's enemies trickle in over this many seconds instead of all at once.
@export var spawn_spread_seconds: float = 20.0
@export var max_spawns_per_frame: int = 6
## Hard limit of living enemies; spawning pauses while it is reached.
@export var max_enemies: int = 500


# --------------------------------------------------
# ENEMY VARIETY
# --------------------------------------------------

@export_group("Hunger")
## true: the NPCs of the event get hungry like all NPCs. Their hunger doubles with every rarity step, so a mythical NPC
## starves after about 2-3 minutes (it has no way to eat) and then moves and hits at half strength. false: they never get hungry.
@export var event_npcs_get_hungry: bool = true


@export_group("Enemy Variety")
# Share of spawns that are enemy2 / enemy3. The rest are enemy1.
# If both together exceed 1.0 they are scaled down proportionally.
@export_range(0.0, 1.0) var enemy2_chance: float = 0.3
@export_range(0.0, 1.0) var enemy3_chance: float = 0.1


# --------------------------------------------------
# WORLD VALIDATION
# --------------------------------------------------

@export_group("World Boundaries")
@export var edge_margin: float = 50.0
@export var max_spawn_attempts: int = 40
@export var avoid_screen: bool = false
@export var offscreen_margin: float = 10.0


# --------------------------------------------------
# RUNTIME VARIABLES
# --------------------------------------------------

signal wave_started(wave: int, enemy_count: int, rank_tier: int)

var player: Node2D
var manager: NpcManager
## The hourglass. Only exists while the event is active.
var hud: WaveHud
var alive_enemies: int = 0

var game_elapsed_seconds: float = 0.0
var current_wave: int = 0

var _alive: Dictionary = {}  # instance id -> true
var _queue: Array[int] = []  # rarity tier of every enemy still to spawn
var _spawn_rate: float = 0.0
var _spawn_budget: float = 0.0
var _wave_clock: float = 0.0
var _world_rect: Rect2 = Rect2()
var _safe_rect: Rect2 = Rect2()


func _ready() -> void:
	event_id = &"wave"
	display_name = "Wave event"
	player = get_tree().get_first_node_in_group("player") as Node2D

	if player == null:
		push_error("WaveEvent: No Node2D player found in group 'player'.")
		set_process(false)
		return

	if enemy_container == null:
		enemy_container = get_parent() as Node2D

	if enemy_container == null:
		push_error("WaveEvent: enemy_container must reference a Node2D.")
		set_process(false)
		return

	_sanitize_exports()

	# The inspector values are the defaults of the developer menu (see DevSettings).
	if not DevSettings.initialized:
		DevSettings.init_from_spawner(self)

	_world_rect = _compute_world_rect()
	_safe_rect = _world_rect.grow(-maxf(0.0, edge_margin))
	_setup_manager()

	# Nothing happens until the event is started.
	set_process(false)


func _on_start() -> void:
	current_wave = 0
	_wave_clock = 0.0
	game_elapsed_seconds = 0.0
	_queue.clear()
	_spawn_budget = 0.0

	# The hourglass only exists while the event runs.
	hud = WaveHud.new()
	hud.name = "WaveHud"
	add_child(hud)

	# Everybody (except unique NPCs) turns hostile.
	Relations.event_all_hostile = true
	set_process(true)


func _on_stop() -> void:
	set_process(false)
	_queue.clear()
	Relations.event_all_hostile = false
	if is_instance_valid(hud):
		hud.queue_free()
	hud = null

	# The NPCs of the event leave with it.
	for node in get_tree().get_nodes_in_group("event_npc"):
		node.queue_free()


# Sanitize exported values so invalid Inspector settings do not break spawning.
func _sanitize_exports() -> void:
	max_enemies = maxi(0, max_enemies)
	wave_duration = maxf(1.0, wave_duration)
	first_wave_enemies = maxi(0, first_wave_enemies)
	first_wave_variants = maxi(0, first_wave_variants)
	waves_per_cycle = maxi(1, waves_per_cycle)
	spawn_spread_seconds = maxf(1.0, spawn_spread_seconds)
	max_spawns_per_frame = maxi(1, max_spawns_per_frame)
	max_spawn_attempts = maxi(1, max_spawn_attempts)
	safe_radius = maxf(0.0, safe_radius)
	min_spawn_distance = maxf(min_spawn_distance, safe_radius)
	max_spawn_distance = maxf(max_spawn_distance, min_spawn_distance)
	spawn_arc_degrees = clampf(spawn_arc_degrees, 0.0, 360.0)


func _setup_manager() -> void:
	manager = NpcManager.find(self)
	if manager == null:
		manager = NpcManager.new()
		manager.name = "NpcManager"
		add_child(manager)

	# Keep enemies a few pixels inside the walls, even while knocked back.
	if _world_rect.size.x > 0.0 and _world_rect.size.y > 0.0:
		manager.world_rect = _world_rect.grow(-8.0)


# --------------------------------------------------
# MAIN LOOP
# --------------------------------------------------

# _process (not Time.get_ticks_msec): the wave clock stops while the game is paused.
func _process(delta: float) -> void:
	if not is_instance_valid(player):
		push_warning("WaveEvent: Player is no longer valid; spawning stopped.")
		set_process(false)
		return

	game_elapsed_seconds += delta

	# A countdown per wave (not total time / duration), so the duration can be changed live
	# in the developer menu without waves jumping or stalling.
	_wave_clock += delta
	if current_wave == 0 or _wave_clock >= DevSettings.wave_duration:
		_wave_clock = 0.0
		_start_wave(current_wave + 1)

	if is_instance_valid(hud):
		hud.set_clock(_wave_clock, DevSettings.wave_duration)

	_update_spawn_direction()
	_release_spawns(delta)


# --------------------------------------------------
# WAVES
# --------------------------------------------------

## What a wave consists of. Example with the defaults:
##   wave 1: 10 + 1 rare   wave 2: 20 + 2   wave 3: 40 + 4   wave 4: 80 + 8   wave 5: 160 + 16
##   wave 6: back to 10 + 1, but everything ranked up one step (uncommon / legendary), and so on.
func get_wave_info(wave: int) -> Dictionary:
	var per_cycle: int = maxi(1, DevSettings.waves_per_cycle)
	var cycle: int = floori(float(wave - 1) / float(per_cycle))
	var step: int = (wave - 1) % per_cycle if DevSettings.reset_count_each_cycle else wave - 1
	var factor: float = pow(DevSettings.wave_growth, float(mini(step, 20)))

	return {
		"enemies": roundi(float(DevSettings.first_wave_enemies) * factor),
		"variants": roundi(float(DevSettings.first_wave_variants) * factor),
		"rank": Rarity.clamp_tier(cycle),
		"variant_rank": Rarity.clamp_tier(variant_rarity + cycle),
	}


func _start_wave(wave: int) -> void:
	current_wave = wave

	var info: Dictionary = get_wave_info(wave)
	var enemies: int = info["enemies"]
	var variants: int = info["variants"]
	var rank: int = info["rank"]
	var variant_rank: int = info["variant_rank"]

	for i in enemies:
		_queue.append(_roll_rarity(rank))
	for i in variants:
		_queue.append(variant_rank)
	_queue.shuffle()

	# Leftovers of the previous wave (e.g. blocked by max_enemies) are simply included.
	_spawn_rate = float(_queue.size()) / maxf(DevSettings.spawn_spread_seconds, 1.0)
	_spawn_budget = 0.0

	if is_instance_valid(hud):
		hud.show_wave(wave, rank)
	wave_started.emit(wave, enemies + variants, rank)

	# The shop gets new offers (the window opens with T, the game does not pause by itself).
	var upgrade_menu := get_tree().get_first_node_in_group("upgrade_menu") as UpgradeMenu
	if upgrade_menu != null:
		upgrade_menu.start_wave(wave, rank)


# Extra ranks on top of the wave rank (developer menu: "Random extra rank"). Off by default.
func _roll_rarity(base_rank: int) -> int:
	if not DevSettings.random_rarity:
		return base_rank

	var total: float = 0.0
	for weight in DevSettings.rarity_weights:
		total += weight
	if total <= 0.0:
		return base_rank

	var roll: float = randf() * total
	var accumulated: float = 0.0
	for extra in DevSettings.rarity_weights.size():
		accumulated += DevSettings.rarity_weights[extra]
		if roll < accumulated:
			return Rarity.clamp_tier(base_rank + extra)
	return base_rank


# Trickles the queued enemies in over spawn_spread_seconds.
func _release_spawns(delta: float) -> void:
	if _queue.is_empty():
		_spawn_budget = 0.0
		return

	_spawn_budget += _spawn_rate * delta
	var spawned: int = 0

	while _spawn_budget >= 1.0 and not _queue.is_empty() and spawned < max_spawns_per_frame:
		if alive_enemies >= DevSettings.max_enemies:
			_spawn_budget = minf(_spawn_budget, 1.0)
			return

		var tier: int = _queue.back()
		if not spawn_enemy(_pick_spawn_angle(), tier):
			return  # no valid position right now, try again next frame

		_queue.pop_back()
		_spawn_budget -= 1.0
		spawned += 1


func _update_spawn_direction() -> void:
	if not follow_player_movement:
		return
	var movement: Vector2 = _get_player_velocity()
	if movement.length() > movement_deadzone:
		last_movement_direction = movement.normalized()


func _pick_spawn_angle() -> float:
	if not follow_player_movement:
		return randf() * TAU
	var half_arc: float = deg_to_rad(spawn_arc_degrees) / 2.0
	return last_movement_direction.angle() + randf_range(-half_arc, half_arc)


func _get_player_velocity() -> Vector2:
	var body := player as CharacterBody2D
	if body == null:
		return Vector2.ZERO
	return body.velocity


func spawn_enemy(angle: float, rarity_tier: int = 0) -> bool:
	if not is_instance_valid(player) or not is_instance_valid(enemy_container):
		return false

	for attempt in range(max_spawn_attempts):
		# If the exact angle is blocked (e.g. outside the world), try nearby angles.
		var try_angle: float = angle
		if attempt > 0:
			try_angle += randf_range(-0.6, 0.6)

		var radius: float = randf_range(min_spawn_distance, max_spawn_distance)
		var candidate: Vector2 = player.global_position + Vector2.from_angle(try_angle) * radius

		if not is_inside_world(candidate):
			continue
		if is_too_close_to_player(candidate):
			continue
		if is_inside_forbidden_zone(candidate):
			continue
		if avoid_screen and is_on_screen(candidate):
			continue

		var scene_to_spawn: PackedScene = _pick_enemy_scene()
		if scene_to_spawn == null:
			push_error("WaveEvent: No valid enemy scene assigned for this spawn.")
			return false

		var node: Node = scene_to_spawn.instantiate()
		var enemy := node as Node2D
		if enemy == null:
			node.free()
			push_error("WaveEvent: Enemy scene root must inherit from Node2D.")
			return false

		# Rarity must be set before the enemy enters the tree (its _ready applies it).
		var character := enemy as NpcCharacter
		if character != null:
			character.rarity = Rarity.clamp_tier(rarity_tier) as Rarity.Tier
			character.is_event_npc = true  # hostile, drops by rarity
			character.hunger_enabled = event_npcs_get_hungry
			enemy.add_to_group("event_npc")

		# Set the correct local position before adding the enemy to the scene tree.
		enemy.position = enemy_container.to_local(candidate)
		enemy_container.add_child(enemy)
		_track(enemy)
		return true

	# No valid position found after all attempts.
	return false


# --------------------------------------------------
# ENEMY SELECTION
# --------------------------------------------------

# Weighted pick of the enemy type. The three chances are relative weights (developer menu).
func _pick_enemy_scene() -> PackedScene:
	var weight1: float = DevSettings.enemy1_chance if enemy_scene != null else 0.0
	var weight2: float = DevSettings.enemy2_chance if enemy2_scene != null else 0.0
	var weight3: float = DevSettings.enemy3_chance if enemy3_scene != null else 0.0

	var total: float = weight1 + weight2 + weight3
	if total <= 0.0:
		return enemy_scene

	var roll: float = randf() * total
	if roll < weight1:
		return enemy_scene
	if roll < weight1 + weight2:
		return enemy2_scene
	return enemy3_scene


# --------------------------------------------------
# ENEMY COUNTING
# --------------------------------------------------

func _track(enemy: Node2D) -> void:
	var id: int = enemy.get_instance_id()
	_alive[id] = true
	alive_enemies = _alive.size()

	enemy.tree_exiting.connect(_on_enemy_gone.bind(id), CONNECT_ONE_SHOT)
	# A dying enemy (death animation) stops counting right away.
	if enemy.has_signal("died"):
		enemy.connect("died", _on_enemy_died.bind(id), CONNECT_ONE_SHOT)


func _on_enemy_gone(id: int) -> void:
	_alive.erase(id)
	alive_enemies = _alive.size()


func _on_enemy_died(_enemy: Node, id: int) -> void:
	_on_enemy_gone(id)


# --------------------------------------------------
# WORLD BOUNDARIES
# --------------------------------------------------

func _compute_world_rect() -> Rect2:
	if not is_instance_valid(Background) or Background.texture == null:
		return Rect2()

	# Transform all four corners so scaled/rotated backgrounds are bounded correctly.
	var local_rect: Rect2 = Background.get_rect()
	var corners: Array[Vector2] = [
		Background.to_global(local_rect.position),
		Background.to_global(Vector2(local_rect.end.x, local_rect.position.y)),
		Background.to_global(Vector2(local_rect.position.x, local_rect.end.y)),
		Background.to_global(local_rect.end)
	]

	var minimum: Vector2 = corners[0]
	var maximum: Vector2 = corners[0]
	for corner in corners:
		minimum = minimum.min(corner)
		maximum = maximum.max(corner)

	return Rect2(minimum, maximum - minimum)


func is_inside_world(pos: Vector2) -> bool:
	if is_instance_valid(manager) and manager.is_blocked(pos):
		return false

	if _world_rect.size.x <= 0.0 or _world_rect.size.y <= 0.0:
		return true  # no background assigned: no limits

	if _safe_rect.size.x <= 0.0 or _safe_rect.size.y <= 0.0:
		return false

	return _safe_rect.has_point(pos)


func is_too_close_to_player(pos: Vector2) -> bool:
	if not is_instance_valid(player):
		return true

	var safe: float = maxf(safe_radius, 0.0)
	return pos.distance_squared_to(player.global_position) < safe * safe


func is_inside_forbidden_zone(pos: Vector2) -> bool:
	if not is_instance_valid(no_spawn_tiles):
		return false

	var local_pos: Vector2 = no_spawn_tiles.to_local(pos)
	var cell: Vector2i = no_spawn_tiles.local_to_map(local_pos)
	return no_spawn_tiles.get_cell_source_id(cell) != -1


func is_on_screen(pos: Vector2) -> bool:
	var screen_to_world: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var visible_rect: Rect2 = screen_to_world * get_viewport().get_visible_rect()
	return visible_rect.grow(maxf(0.0, offscreen_margin)).has_point(pos)
