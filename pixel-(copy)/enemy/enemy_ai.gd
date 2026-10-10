
extends Node
class_name EnemyAI

enum State {
	WANDER,
	CHASE,
	ATTACK,
	FLEE
}

@export var wander_behavior: WanderBehavior = WanderBehavior.new()
@export var chase_behavior: ChaseBehavior = ChaseBehavior.new()
@export var attack_behavior: AttackBehavior = AttackBehavior.new()
@export var flee_behavior: FleeBehavior = FleeBehavior.new()

@export_group("Flee Settings")
@export var flee_recovery_margin: float = 0.15
@export var target_lose_range_multiplier: float = 1.2

@export_group("Encirclement")
@export var encircle_enabled: bool = true
@export var encircle_radius: float = 100.0
@export var encircle_min_radius: float = 38.0
@export var slot_update_interval: float = 0.25

@export_group("Separation")
@export var separation_radius: float = 42.0
@export var separation_strength: float = 1.5

var current_state: State = State.WANDER
var active_behavior: EnemyBehavior
var behaviors: Dictionary = {}

var player_ref: Node2D
var _initialized: bool = false
var _slot_timer: float = 0.0
var _encircle_target_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Every enemy needs to be in the "enemies" group.
	# Assign this group to the EnemyCharacter node.
	behaviors = {
		State.WANDER: wander_behavior.duplicate(true),
		State.CHASE: chase_behavior.duplicate(true),
		State.ATTACK: attack_behavior.duplicate(true),
		State.FLEE: flee_behavior.duplicate(true)
	}


func update_ai(enemy: EnemyCharacter, delta: float) -> void:
	if not _initialized:
		_initialized = true
		active_behavior = behaviors[State.WANDER]
		active_behavior.enter(enemy)

	_update_target(enemy)

	var next_state: State = State.WANDER

	if is_instance_valid(enemy.target):
		var distance := enemy.global_position.distance_to(
			enemy.target.global_position
		)

		var health_ratio := enemy.health / maxf(enemy.max_health, 0.001)

		if current_state == State.FLEE:
			if health_ratio < enemy.flee_health_ratio + flee_recovery_margin:
				next_state = State.FLEE
			elif distance <= enemy.attack_range:
				next_state = State.ATTACK
			else:
				next_state = State.CHASE

		elif health_ratio <= enemy.flee_health_ratio:
			next_state = State.FLEE
		elif distance <= enemy.attack_range:
			next_state = State.ATTACK
		else:
			next_state = State.CHASE

	_switch_to(next_state, enemy)

	if current_state == State.CHASE and encircle_enabled:
		_update_encircle_target(enemy, delta)

	if active_behavior != null:
		active_behavior.update(enemy, delta)


func _update_target(enemy: EnemyCharacter) -> void:
	if is_instance_valid(enemy.target):
		var distance := enemy.global_position.distance_to(
			enemy.target.global_position
		)
		if distance > enemy.detection_range * target_lose_range_multiplier:
			enemy.target = null

	if not is_instance_valid(enemy.target):
		if not is_instance_valid(player_ref):
			player_ref = enemy.get_tree().get_first_node_in_group(
				"player"
			) as Node2D

		if is_instance_valid(player_ref):
			if enemy.global_position.distance_to(
				player_ref.global_position
			) <= enemy.detection_range:
				enemy.target = player_ref


func _update_encircle_target(
	enemy: EnemyCharacter,
	delta: float
) -> void:
	if not is_instance_valid(enemy.target):
		return

	_slot_timer -= delta

	if _slot_timer > 0.0:
		return

	_slot_timer = slot_update_interval

	var enemies: Array[Node] = []
	for node in enemy.get_tree().get_nodes_in_group("enemies"):
		if node is EnemyCharacter and node != enemy:
			if is_instance_valid(node) and node.target == enemy.target:
				enemies.append(node)

	# Sort by instance ID so each enemy gets a reproducible slot
	# while the group membership remains unchanged.
	enemies.append(enemy)
	enemies.sort_custom(
		func(a: Node, b: Node) -> bool:
			return a.get_instance_id() < b.get_instance_id()
	)

	var slot_index := enemies.find(enemy)
	var slot_count := enemies.size()
	var angle := TAU * float(slot_index) / float(slot_count)

	# Offset slots based on the enemy's index around the player.
	var offset := Vector2.RIGHT.rotated(angle) * encircle_radius
	_encircle_target_pos = enemy.target.global_position + offset


# Call this from ChaseBehavior to get the desired encirclement position.
func get_encircle_target() -> Vector2:
	return _encircle_target_pos


# Call this from ChaseBehavior to avoid crowding nearby enemies.
func get_separation_direction(enemy: EnemyCharacter) -> Vector2:
	var push := Vector2.ZERO

	for node in enemy.get_tree().get_nodes_in_group("enemies"):
		if node == enemy or not node is EnemyCharacter:
			continue

		var other := node as EnemyCharacter
		if not is_instance_valid(other):
			continue

		var offset := enemy.global_position - other.global_position
		var distance := offset.length()

		if distance > 0.001 and distance < separation_radius:
			var weight := 1.0 - distance / separation_radius
			push += offset.normalized() * weight

	if push.length_squared() > 0.001:
		return push.normalized()

	return Vector2.ZERO


func get_encircle_radius() -> float:
	return maxf(encircle_min_radius, encircle_radius)


func _switch_to(next_state: State, enemy: EnemyCharacter) -> void:
	if next_state == current_state:
		return

	if active_behavior != null:
		active_behavior.exit(enemy)

	current_state = next_state
	active_behavior = behaviors[current_state]
	active_behavior.enter(enemy)
