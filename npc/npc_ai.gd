extends Node
class_name NpcAI
## Decides WHAT the NPC does (state machine). The behaviors decide HOW.
## The NpcCharacter owns movement and animation; this node only picks
## the state and runs the active behavior, which writes desired_direction/speed.
##
## Who is a target? Whoever the NPC is hostile to (the player, or NPCs of an enemy faction, see Relations),
## and anybody who attacked it recently. With no target a hungry NPC goes to get food (TASK), otherwise it wanders.
## Friendly NPCs share food with each other.

enum State {
	WANDER,
	CHASE,
	ATTACK,
	FLEE,
	TASK  ## doing something for a need (getting food)
}

@export var wander_behavior: WanderBehavior = WanderBehavior.new()
@export var chase_behavior: ChaseBehavior = ChaseBehavior.new()
@export var attack_behavior: AttackBehavior = AttackBehavior.new()
@export var flee_behavior: FleeBehavior = FleeBehavior.new()
@export var task_behavior: SeekFoodBehavior = SeekFoodBehavior.new()

@export_group("Targeting")
@export var flee_recovery_margin: float = 0.15
@export var target_lose_range_multiplier: float = 1.2
## Leaves ATTACK only when the target is this much farther than attack_range
## (prevents flickering between CHASE and ATTACK at the boundary).
@export var attack_exit_margin: float = 0.3

@export_group("Encirclement")
@export var encircle_enabled: bool = true
## Ring radius around the target. Once an enemy is inside it, it stops
## circling and simply closes in on the target.
@export var encircle_radius: float = 100.0

@export_group("Separation")
@export var separation_strength: float = 1.5
## Separation is recomputed this often (staggered per enemy) instead of every frame.
@export var separation_interval: float = 0.1

var current_state: State = State.WANDER
var active_behavior: NpcBehavior
var behaviors: Dictionary = {}

## Set by the NpcManager. NAN = no slot assigned yet.
var slot_angle: float = NAN
## True once the enemy reached the ring and is closing in.
var slot_committed: bool = false
var manager: NpcManager

var _enemy: NpcCharacter
var _player_ref: Node2D
var _initialized: bool = false
var _distance_to_target: float = INF
var _separation: Vector2 = Vector2.ZERO
var _separation_timer: float = 0.0
var _manager_retry: float = 0.0
var _target_timer: float = 0.0
var _social_timer: float = 0.0


func _ready() -> void:
	behaviors = {
		State.WANDER: wander_behavior.duplicate(true),
		State.CHASE: chase_behavior.duplicate(true),
		State.ATTACK: attack_behavior.duplicate(true),
		State.FLEE: flee_behavior.duplicate(true),
		State.TASK: task_behavior.duplicate(true)
	}
	# Spread the work: not every enemy recomputes in the same frame.
	_separation_timer = randf() * separation_interval
	_target_timer = randf() * 0.25
	_social_timer = randf() * 1.5


## Applies the approach style of an NpcStats. Called once by the NpcCharacter.
func configure(stats: NpcStats) -> void:
	match stats.approach:
		NpcStats.Approach.DIRECT:
			encircle_enabled = false
		NpcStats.Approach.ENCIRCLE:
			encircle_enabled = true
		NpcStats.Approach.KEEP_DISTANCE:
			encircle_enabled = false
			var ranged := RangedAttackBehavior.new()
			ranged.min_distance = stats.min_distance
			ranged.max_distance = stats.max_distance
			behaviors[State.ATTACK] = ranged

	var attack := behaviors[State.ATTACK] as AttackBehavior
	attack.attack_cooldown = stats.attack_cooldown


func update_ai(enemy: NpcCharacter, delta: float) -> void:
	if not _initialized:
		_initialized = true
		_enemy = enemy
		active_behavior = behaviors[State.WANDER]
		active_behavior.enter(enemy)

	_find_manager(delta)
	_update_target(enemy, delta)
	_update_social(enemy, delta)

	_distance_to_target = INF
	if is_instance_valid(enemy.target):
		_distance_to_target = enemy.global_position.distance_to(enemy.target.global_position)

	_switch_to(_decide_state(enemy), enemy)

	if current_state == State.CHASE:
		_update_chase_helpers(delta)

	if active_behavior != null:
		active_behavior.update(enemy, delta)


# --------------------------------------------------
# SERVICES FOR BEHAVIORS / MANAGER
# --------------------------------------------------

## Used by the NpcManager: does this enemy need an encirclement slot?
func wants_slot() -> bool:
	return (
		encircle_enabled
		and current_state == State.CHASE
		and not slot_committed
		and is_instance_valid(_enemy)
		and is_instance_valid(_enemy.target)
	)


func is_slot_active() -> bool:
	return encircle_enabled and not slot_committed and not is_nan(slot_angle)


## Where the enemy should walk to: its ring slot, or the target itself.
func get_approach_point(enemy: NpcCharacter) -> Vector2:
	var target_pos: Vector2 = enemy.target.global_position
	if not is_slot_active():
		return target_pos
	return target_pos + Vector2.from_angle(slot_angle) * encircle_radius


## Cached push direction away from crowded neighbours.
func get_separation() -> Vector2:
	return _separation


# --------------------------------------------------
# INTERNALS
# --------------------------------------------------

func _find_manager(delta: float) -> void:
	if is_instance_valid(manager):
		return
	_manager_retry -= delta
	if _manager_retry <= 0.0:
		_manager_retry = 1.0
		manager = NpcManager.find(self)


func _update_chase_helpers(delta: float) -> void:
	if not slot_committed and _distance_to_target <= encircle_radius:
		slot_committed = true

	_separation_timer -= delta
	if _separation_timer <= 0.0:
		_separation_timer = separation_interval
		if is_instance_valid(manager) and is_instance_valid(_enemy):
			_separation = manager.get_separation(_enemy)
		else:
			_separation = Vector2.ZERO


# Picks the target: whoever the NPC is hostile to (the player, NPCs of an enemy faction) or who attacked it.
func _update_target(npc: NpcCharacter, delta: float) -> void:
	# Keep the current target while it is alive, close enough and still an enemy (or a grudge).
	if is_instance_valid(npc.target):
		var keep: bool = true
		var is_player: bool = npc.target.is_in_group("player")
		var range_limit: float = npc.detection_range if is_player else npc.npc_detection_range * npc.aggression_scale()
		var other := npc.target as NpcCharacter
		if npc.global_position.distance_to(npc.target.global_position) > range_limit * target_lose_range_multiplier:
			keep = false
		elif other != null and other.dead:
			keep = false
		elif not npc.has_grudge_against(npc.target) and not npc.is_hostile_to(npc.target):
			keep = false  # e.g. the relation changed (the event ended)
		if not keep:
			npc.target = null

	if is_instance_valid(npc.target):
		return

	# Looking around costs a little: not every frame.
	_target_timer -= delta
	if _target_timer > 0.0:
		return
	_target_timer = 0.25

	var best: Node2D = null
	var best_distance: float = INF

	if is_instance_valid(npc.grudge_target) and npc._grudge_left > 0.0:
		var grudge_distance: float = npc.global_position.distance_to(npc.grudge_target.global_position)
		if grudge_distance <= npc.detection_range:
			best = npc.grudge_target
			best_distance = grudge_distance

	# The player, if the NPC is hostile to them.
	if best == null:
		if not is_instance_valid(_player_ref):
			_player_ref = npc.get_tree().get_first_node_in_group("player") as Node2D
		if is_instance_valid(_player_ref) and npc.is_hostile_to(_player_ref):
			var player_distance: float = npc.global_position.distance_to(_player_ref.global_position)
			if player_distance <= npc.detection_range:
				best = _player_ref
				best_distance = player_distance

	# Other NPCs it is hostile to (police against gangs, ...), only nearby ones: the manager's grid finds them.
	if is_instance_valid(manager) and not Relations.event_all_hostile:
		for other in manager.find_nearby(npc, npc.npc_detection_range * npc.aggression_scale()):
			if other.dead or not npc.is_hostile_to(other):
				continue
			var distance: float = npc.global_position.distance_to(other.global_position)
			if distance < best_distance:
				best = other
				best_distance = distance

	npc.target = best


# Friendly NPCs help each other: somebody with spare food gives one to a hungry friend nearby.
func _update_social(npc: NpcCharacter, delta: float) -> void:
	_social_timer -= delta
	if _social_timer > 0.0:
		return
	_social_timer = 1.5 + randf() * 0.5

	if not is_instance_valid(manager) or npc.dead or npc.is_event_npc:
		return
	if npc.happiness > Happiness.State.UNREST or npc.food_count() < 2:
		return  # unhappy NPCs don't share, and it needs some to spare

	for other in manager.find_nearby(npc, 60.0):
		if other.dead or other.hunger.value >= 30.0 or other.food_count() > 0:
			continue
		if Relations.between(npc, other) == Relation.Level.FRIENDLY:
			npc.give_food_to(other)
			return


func _decide_state(enemy: NpcCharacter) -> State:
	if not is_instance_valid(enemy.target):
		# Nobody to fight: a hungry NPC goes to get food, otherwise it wanders.
		return State.TASK if enemy.wants_food() else State.WANDER

	var health_ratio: float = enemy.health / maxf(enemy.max_health, 0.001)

	if current_state == State.FLEE:
		# Stay in FLEE until health has recovered past the margin.
		if health_ratio < enemy.flee_health_ratio + flee_recovery_margin:
			return State.FLEE
	elif health_ratio <= enemy.flee_health_ratio:
		return State.FLEE

	var attack_range: float = enemy.attack_range
	if current_state == State.ATTACK:
		attack_range *= 1.0 + attack_exit_margin

	if _distance_to_target <= attack_range:
		return State.ATTACK
	return State.CHASE


func _switch_to(next_state: State, enemy: NpcCharacter) -> void:
	if next_state == current_state:
		return

	if active_behavior != null:
		active_behavior.exit(enemy)

	current_state = next_state
	enemy.look_direction = Vector2.ZERO
	slot_committed = false
	slot_angle = NAN
	_separation = Vector2.ZERO

	active_behavior = behaviors[current_state]
	active_behavior.enter(enemy)
