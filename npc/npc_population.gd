extends Node
class_name NpcPopulation
## Fills the world with NPCs during NORMAL gameplay (the wave event has its own spawner and pauses this one).
##
## It keeps `target_count` NPCs alive around the player: new ones appear off screen, and ones that are far away and
## out of sight are removed again, so the part of the city around the player is always alive. Each NPC gets a faction
## (by `faction_weights`) and a rarity, carries some coins and food, gets hungry over time, looks for food when it is
## hungry, fights NPCs of enemy factions and shares food with friends (see NpcAI, Relations, NpcGoal).
##
## Unique NPCs are not placed yet: give an NpcStats a `unique_id` and spawn it like any other NPC.

@export var npc_scenes: Array[PackedScene] = [
	preload("res://npc/scenes/npc_basic.tscn"),
	preload("res://npc/scenes/npc_woman.tscn"),
	preload("res://npc/scenes/npc_speeder.tscn"),
]
@export var Background: Sprite2D
@export var npc_container: Node2D

@export_group("Population")
@export var target_count: int = 24
## One NPC is added at most this often (seconds) while there are too few.
@export var spawn_interval: float = 0.6
@export var min_spawn_distance: float = 200.0
@export var max_spawn_distance: float = 420.0
## NPCs farther away than this (and out of sight) are removed.
@export var despawn_distance: float = 800.0
@export var edge_margin: float = 50.0
@export var max_spawn_attempts: int = 30

@export_group("Factions")
## Relative weights of the factions among the NPCs. 0 = none (animal, demon, holy and alien have no art yet).
@export var faction_weights: Dictionary = {
	Faction.Id.CIVILIAN: 60.0, Faction.Id.POLICE: 8.0, Faction.Id.EMERGENCY: 4.0, Faction.Id.MILITARY: 2.0,
	Faction.Id.CULT: 3.0, Faction.Id.CHURCH: 4.0, Faction.Id.GANG1: 6.0, Faction.Id.GANG2: 6.0, Faction.Id.GANG3: 6.0,
}

@export_group("Rarity")
@export_range(0.0, 1.0) var uncommon_chance: float = 0.10
@export_range(0.0, 1.0) var rare_chance: float = 0.03

var player: Node2D
var manager: NpcManager

var _world_rect: Rect2 = Rect2()
var _safe_rect: Rect2 = Rect2()
var _spawn_timer: float = 0.0
var _despawn_timer: float = 0.0


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	if npc_container == null:
		npc_container = get_parent() as Node2D
	if player == null or npc_container == null:
		push_error("NpcPopulation: needs a player (group 'player') and a Node2D container.")
		set_process(false)
		return

	_world_rect = _rect_of(Background)
	_safe_rect = _world_rect.grow(-maxf(edge_margin, 0.0))

	manager = NpcManager.find(self)
	if manager == null:
		manager = NpcManager.new()
		manager.name = "NpcManager"
		add_child(manager)
	if manager.world_rect.size.x <= 0.0 and _world_rect.size.x > 0.0:
		manager.world_rect = _world_rect.grow(-8.0)

	_initial_fill.call_deferred()


# The first NPCs are there right away (off screen, around the player).
func _initial_fill() -> void:
	for i in target_count:
		if not _spawn_one():
			break


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	# While the wave event runs it does the spawning: no normal NPCs are added.
	if Relations.event_all_hostile:
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = spawn_interval
		if _count_normal_npcs() < target_count:
			_spawn_one()

	_despawn_timer -= delta
	if _despawn_timer <= 0.0:
		_despawn_timer = 1.0
		_despawn_far_npcs()


func _count_normal_npcs() -> int:
	var count: int = 0
	for node in get_tree().get_nodes_in_group("npc"):
		var npc := node as NpcCharacter
		if npc != null and not npc.is_event_npc and not npc.dead:
			count += 1
	return count


func _spawn_one() -> bool:
	if npc_scenes.is_empty():
		return false

	for attempt in max_spawn_attempts:
		var angle: float = randf() * TAU
		var candidate: Vector2 = player.global_position + Vector2.from_angle(angle) * randf_range(min_spawn_distance, max_spawn_distance)
		if not _is_valid_spawn(candidate):
			continue

		var scene: PackedScene = npc_scenes[randi() % npc_scenes.size()]
		var npc := scene.instantiate() as NpcCharacter
		if npc == null:
			return false

		# Faction and rarity must be set before the NPC enters the tree (its _ready applies them).
		npc.faction = _pick_faction()
		npc.faction_assigned = true
		npc.rarity = _pick_rarity()
		npc.position = npc_container.to_local(candidate)
		npc_container.add_child(npc)
		return true
	return false


func _is_valid_spawn(pos: Vector2) -> bool:
	if is_instance_valid(manager) and manager.is_blocked(pos):
		return false
	if _world_rect.size.x > 0.0 and not _safe_rect.has_point(pos):
		return false
	return not _is_on_screen(pos)


func _pick_faction() -> Faction.Id:
	var total: float = 0.0
	for weight in faction_weights.values():
		total += float(weight)
	if total <= 0.0:
		return Faction.Id.CIVILIAN

	var roll: float = randf() * total
	var accumulated: float = 0.0
	for faction in faction_weights:
		accumulated += float(faction_weights[faction])
		if roll < accumulated:
			return faction
	return Faction.Id.CIVILIAN


func _pick_rarity() -> Rarity.Tier:
	var roll: float = randf()
	if roll < rare_chance:
		return Rarity.Tier.RARE
	if roll < rare_chance + uncommon_chance:
		return Rarity.Tier.UNCOMMON
	return Rarity.Tier.COMMON


# NPCs far from the player and out of sight are removed (the world around the player stays populated).
func _despawn_far_npcs() -> void:
	var limit: float = despawn_distance * despawn_distance
	for node in get_tree().get_nodes_in_group("npc"):
		var npc := node as NpcCharacter
		if npc == null or npc.is_event_npc or npc.dead:
			continue
		if npc.global_position.distance_squared_to(player.global_position) > limit and not _is_on_screen(npc.global_position):
			npc.queue_free()


func _is_on_screen(pos: Vector2) -> bool:
	var screen_to_world: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var visible_rect: Rect2 = screen_to_world * get_viewport().get_visible_rect()
	return visible_rect.grow(30.0).has_point(pos)


# The area of a sprite in the world (also for scaled sprites).
static func _rect_of(sprite: Sprite2D) -> Rect2:
	if not is_instance_valid(sprite) or sprite.texture == null:
		return Rect2()
	var local_rect: Rect2 = sprite.get_rect()
	var corners: Array[Vector2] = [
		sprite.to_global(local_rect.position),
		sprite.to_global(Vector2(local_rect.end.x, local_rect.position.y)),
		sprite.to_global(Vector2(local_rect.position.x, local_rect.end.y)),
		sprite.to_global(local_rect.end),
	]
	var minimum: Vector2 = corners[0]
	var maximum: Vector2 = corners[0]
	for corner in corners:
		minimum = minimum.min(corner)
		maximum = maximum.max(corner)
	return Rect2(minimum, maximum - minimum)
