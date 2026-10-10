extends Node2D

# --------------------------------------------------
# ENEMY SCENES
# --------------------------------------------------

@export var enemy_scene: PackedScene = preload("res://enemy.tscn")
@export var enemy2_scene: PackedScene = preload("res://enemy2.tscn")
@export var enemy3_scene: PackedScene = preload("res://enemy3.tscn")

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

# Evenly space enemies instead of choosing completely random angles.
@export var balanced_circle: bool = true

# Add a random angular offset to full-circle balanced formations each wave.
@export var randomize_circle_rotation: bool = true


# --------------------------------------------------
# SPAWN TIMING
# --------------------------------------------------

@export_group("Spawn Timing")
@export var spawn_interval: float = 1.5
@export var min_spawn_interval: float = 0.25

# Seconds removed from the interval per minute of play.
@export var interval_decrease_per_minute: float = 0.12


# --------------------------------------------------
# ENEMY AMOUNTS
# --------------------------------------------------

@export_group("Enemy Amounts")

# Absolute maximum number of living enemies.
@export var max_enemies: int = 500

# Starting limit for living enemies.
@export var starting_max_enemies: int = 20

# Increase the living-enemy limit every difficulty step.
@export var max_enemies_increase: int = 10
@export var difficulty_step_seconds: float = 30.0

# Enemies spawned during each timer timeout.
@export var starting_enemies_per_wave: int = 1

# Increase the wave size over time.
@export var enemies_per_wave_increase: int = 1
@export var wave_size_increase_seconds: float = 20.0


# --------------------------------------------------
# ENEMY VARIETY
# --------------------------------------------------

@export_group("Enemy Variety")
@export_range(0.0, 1.0) var enemy2_chance: float = 0.3
@export_range(0.0, 1.0) var enemy3_chance: float = 0.1

# Optional increase in each enemy type's chance per minute.
@export_range(0.0, 1.0) var enemy2_chance_increase_per_minute: float = 0.0
@export_range(0.0, 1.0) var enemy3_chance_increase_per_minute: float = 0.0


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

var player: Node2D
var alive_enemies: int = 0
var spawn_timer: Timer

var game_elapsed_seconds: float = 0.0
var current_spawn_interval: float = 1.5
var current_max_enemies: int = 20
var current_wave_size: int = 1
var current_enemy2_chance: float = 0.3
var current_enemy3_chance: float = 0.1

var start_time_msec: int = 0


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D

	if player == null:
		push_error("EnemySpawner: No Node2D player found in group 'player'.")
		return

	if enemy_container == null:
		enemy_container = get_parent() as Node2D

	if enemy_container == null:
		push_error("EnemySpawner: enemy_container must reference a Node2D.")
		return

	# Sanitize exported values so invalid Inspector settings do not break spawning.
	max_enemies = maxi(0, max_enemies)
	starting_max_enemies = clampi(starting_max_enemies, 0, max_enemies)
	max_enemies_increase = maxi(0, max_enemies_increase)
	starting_enemies_per_wave = maxi(1, starting_enemies_per_wave)
	enemies_per_wave_increase = maxi(0, enemies_per_wave_increase)
	max_spawn_attempts = maxi(1, max_spawn_attempts)
	safe_radius = maxf(0.0, safe_radius)
	min_spawn_distance = maxf(min_spawn_distance, safe_radius)
	max_spawn_distance = maxf(max_spawn_distance, min_spawn_distance)
	min_spawn_interval = maxf(0.05, min_spawn_interval)
	spawn_interval = maxf(min_spawn_interval, spawn_interval)
	spawn_arc_degrees = clampf(spawn_arc_degrees, 0.0, 360.0)

	start_time_msec = Time.get_ticks_msec()
	current_spawn_interval = spawn_interval
	current_max_enemies = starting_max_enemies
	current_wave_size = starting_enemies_per_wave
	current_enemy2_chance = clampf(enemy2_chance, 0.0, 1.0)
	current_enemy3_chance = clampf(enemy3_chance, 0.0, 1.0)

	spawn_timer = Timer.new()
	spawn_timer.name = "EnemySpawnTimer"
	spawn_timer.one_shot = false
	spawn_timer.wait_time = current_spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	spawn_timer.start()


# --------------------------------------------------
# DIFFICULTY PROGRESSION
# --------------------------------------------------

func update_difficulty() -> void:
	game_elapsed_seconds = maxf(
		0.0,
		(float(Time.get_ticks_msec() - start_time_msec) / 1000.0)
	)
	var elapsed_minutes: float = game_elapsed_seconds / 60.0

	# Gradually shorten spawn intervals.
	current_spawn_interval = maxf(
		min_spawn_interval,
		spawn_interval - elapsed_minutes * interval_decrease_per_minute
	)

	# Increase the living-enemy limit at fixed time steps.
	var difficulty_step: int = 0
	if difficulty_step_seconds > 0.0:
		difficulty_step = int(floor(game_elapsed_seconds / difficulty_step_seconds))

	current_max_enemies = mini(
		max_enemies,
		starting_max_enemies + difficulty_step * max_enemies_increase
	)

	# Increase the number of enemies in each wave.
	var wave_step: int = 0
	if wave_size_increase_seconds > 0.0:
		wave_step = int(floor(game_elapsed_seconds / wave_size_increase_seconds))

	current_wave_size = (
		maxi(1, starting_enemies_per_wave)
		+ wave_step * enemies_per_wave_increase
	)

	# Progress each enemy type independently.
	current_enemy2_chance = clampf(
		enemy2_chance + elapsed_minutes * enemy2_chance_increase_per_minute,
		0.0,
		1.0
	)
	current_enemy3_chance = clampf(
		enemy3_chance + elapsed_minutes * enemy3_chance_increase_per_minute,
		0.0,
		1.0
	)


# --------------------------------------------------
# SPAWN TIMER
# --------------------------------------------------

func _on_spawn_timer_timeout() -> void:
	if not is_instance_valid(player):
		if is_instance_valid(spawn_timer):
			spawn_timer.stop()
		push_warning("EnemySpawner: Player is no longer valid; spawning stopped.")
		return

	update_difficulty()

	# Restarting here makes the updated interval apply to the next wave.
	spawn_timer.start(current_spawn_interval)

	if alive_enemies >= current_max_enemies:
		return

	spawn_wave()


# --------------------------------------------------
# CIRCULAR SPAWNING
# --------------------------------------------------

func spawn_wave() -> void:
	if not is_instance_valid(player) or not is_instance_valid(enemy_container):
		return

	var available_slots: int = current_max_enemies - alive_enemies
	var amount_to_spawn: int = mini(current_wave_size, available_slots)
	if amount_to_spawn <= 0:
		return

	# Keep the last direction if the player stops moving.
	if follow_player_movement:
		var movement: Vector2 = _get_player_velocity()
		if movement.length() > movement_deadzone:
			last_movement_direction = movement.normalized()

	var center_angle: float = last_movement_direction.angle()
	if not follow_player_movement:
		center_angle = randf() * TAU

	var arc_radians: float = deg_to_rad(spawn_arc_degrees)
	var start_angle: float = center_angle - arc_radians / 2.0
	var full_circle: bool = spawn_arc_degrees >= 359.9
	var rotation_offset: float = 0.0

	if balanced_circle and full_circle and randomize_circle_rotation:
		rotation_offset = randf_range(0.0, TAU)

	for i in range(amount_to_spawn):
		var angle: float

		if balanced_circle:
			if amount_to_spawn == 1:
				angle = center_angle
			elif full_circle:
				# Do not duplicate the first position at the end of a full circle.
				angle = center_angle + rotation_offset + TAU * float(i) / float(amount_to_spawn)
			else:
				# Partial arcs include both endpoints for even spacing.
				angle = start_angle + arc_radians * float(i) / float(amount_to_spawn - 1)
		else:
			angle = center_angle + randf_range(-arc_radians / 2.0, arc_radians / 2.0)

		spawn_enemy(angle)


func _get_player_velocity() -> Vector2:
	if not is_instance_valid(player):
		return Vector2.ZERO

	# Check the property list before reading velocity; not every player script exposes it.
	for property_info in player.get_property_list():
		if StringName(property_info.get("name", "")) == &"velocity":
			var value: Variant = player.get("velocity")
			if value is Vector2:
				return value
			return Vector2.ZERO

	return Vector2.ZERO


func spawn_enemy(angle: float) -> bool:
	if not is_instance_valid(player) or not is_instance_valid(enemy_container):
		return false

	for _attempt in range(max_spawn_attempts):
		var radius: float = randf_range(min_spawn_distance, max_spawn_distance)
		var candidate: Vector2 = (
			player.global_position + Vector2.from_angle(angle) * radius
		)

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
			push_error("EnemySpawner: No valid enemy scene assigned for this spawn.")
			return false

		var node: Node = scene_to_spawn.instantiate()
		var enemy: Node2D = node as Node2D
		if enemy == null:
			node.free()
			push_error("EnemySpawner: Enemy scene root must inherit from Node2D.")
			return false

		# Set the correct local position before adding the enemy to the scene tree.
		enemy.position = enemy_container.to_local(candidate)
		enemy_container.add_child(enemy)

		_connect_enemy_hitbox(enemy)

		alive_enemies += 1
		enemy.tree_exited.connect(_on_enemy_exited, CONNECT_ONE_SHOT)
		return true

	# No valid position found after all attempts.
	return false


func _connect_enemy_hitbox(enemy: Node2D) -> void:
	var hitbox: Node = enemy.find_child("TouchHitbox", true, false)
	if hitbox == null or not hitbox.has_signal("player_touched"):
		push_warning("EnemySpawner: Enemy has no TouchHitbox with a 'player_touched' signal.")
		return

	if not is_instance_valid(player):
		push_warning("EnemySpawner: Cannot connect hitbox because the player is invalid.")
		return

	if not player.has_method("_on_enemy_player_touched"):
		push_warning("EnemySpawner: Player has no '_on_enemy_player_touched' method.")
		return

	var callback: Callable = Callable(player, "_on_enemy_player_touched")
	if not hitbox.is_connected("player_touched", callback):
		hitbox.connect("player_touched", callback)


# --------------------------------------------------
# ENEMY SELECTION
# --------------------------------------------------

func _pick_enemy_scene() -> PackedScene:
	# Keep the two chances independent, preserving the original selection behavior.
	if enemy2_scene != null and randf() < current_enemy2_chance:
		return enemy2_scene
	if enemy3_scene != null and randf() < current_enemy3_chance:
		return enemy3_scene
	return enemy_scene


# --------------------------------------------------
# ENEMY COUNTING
# --------------------------------------------------

func _on_enemy_exited() -> void:
	alive_enemies = maxi(0, alive_enemies - 1)


# --------------------------------------------------
# WORLD BOUNDARIES
# --------------------------------------------------

func is_inside_world(pos: Vector2) -> bool:
	if not is_instance_valid(Background) or Background.texture == null:
		return true

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

	var world_rect: Rect2 = Rect2(minimum, maximum - minimum)
	var safe_rect: Rect2 = world_rect.grow(-maxf(0.0, edge_margin))
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return false

	return safe_rect.has_point(pos)


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
	var visible_rect: Rect2 = screen_to_world * get_viewport_rect()
	return visible_rect.grow(maxf(0.0, offscreen_margin)).has_point(pos)
