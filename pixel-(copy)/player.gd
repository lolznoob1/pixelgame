extends CharacterBody2D

signal oxygen_depleted

@export var speed: float = 70.0
@export var max_oxygen: float = 100.0
@export var oxygen_regen_rate: float = 10.0
@export var oxygen_loss_base: float = 5.0
@export var ability1_cooldown: float = 5.0
@export var jump_height: float = 24.0
@export var jump_duration: float = 0.35
@export var jump_oxygen_cost: float = 20.0

var oxygen: float = 100.0
var is_oxygen_depleted: bool = false
var can_ability1: bool = true
var attacking: bool = false
var hurt: bool = false
var dead: bool = false
var is_jumping: bool = false
var jump_timer: float = 0.0
var player_visual: Node2D
var visual_start_position: Vector2

# Alle Gegner, die den Spieler momentan berühren
var touching_enemies: Dictionary = {}

@onready var detection_area: Area2D = $DetectionArea
@onready var oxygen_bar: ProgressBar = $CanvasLayer/OxygenBar
@onready var jump_attack_area: Area2D = $JumpAttackArea
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	oxygen = max_oxygen

	oxygen_bar.min_value = 0.0
	oxygen_bar.max_value = max_oxygen
	oxygen_bar.value = oxygen

	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("idle")
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	# Replace Sprite2D with the actual name of your visual node
	player_visual = $AnimatedSprite2D
	visual_start_position = player_visual.position


func _physics_process(_delta: float) -> void:
	# Keine Bewegung während Hurt oder Death
	if dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if hurt:
		velocity *= 0.5
		move_and_slide()
		return

	# Während des Angriffs keine normale Bewegung
	if attacking:
		move_and_slide()
		return

	# Teleport mit Q / ability1
	if Input.is_action_just_pressed("ability1") and can_ability1:
		global_position = get_global_mouse_position()
		velocity = Vector2.ZERO
		can_ability1 = false
		start_teleport_cooldown()
		return

	# Jump Attack
	if Input.is_action_just_pressed("jump_attack"):
		start_jump_attack()
		return

	# WASD-Bewegung
	var direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	velocity = direction * speed

	# Sprite nach links oder rechts drehen
	if direction.x != 0:
		sprite.flip_h = direction.x < 0

	move_and_slide()

	# Schwertangriff
	if Input.is_action_just_pressed("attack"):
		attack()
		return

	# Lauf- und Idle-Animation
	if direction.length() > 0:
		play_animation("walk")
	else:
		play_animation("idle")


func play_animation(anim_name: String) -> void:
	if sprite.animation != anim_name:
		sprite.play(anim_name)


func attack() -> void:
	if dead or hurt or attacking:
		return

	attacking = true
	velocity = Vector2.ZERO
	sprite.play("attack_sword")

	# Add attack hit detection here later.


func _on_animation_finished() -> void:
	match sprite.animation:
		"attack_sword":
			attacking = false
			# Return to idle when the attack finishes
			sprite.play("idle")

		"hurt":
			hurt = false
			sprite.play("idle")

		"death":
			queue_free()

	if oxygen <= 0:
		die()


func die() -> void:
	dead = true
	attacking = false
	hurt = false
	velocity = Vector2.ZERO


func update_jump(delta: float) -> void:
	if not is_jumping:
		return

	jump_timer += delta

	var progress: float = minf(jump_timer / jump_duration, 1.0)

	# Move the sprite upward and then back down
	var jump_offset: float = -sin(progress * PI) * jump_height
	player_visual.position = visual_start_position + Vector2(0, jump_offset)

	if progress >= 1.0:
		is_jumping = false
		jump_timer = 0.0
		player_visual.position = visual_start_position


func start_teleport_cooldown() -> void:
	await get_tree().create_timer(ability1_cooldown).timeout
	can_ability1 = true


func perform_jump_attack() -> void:
	for enemy in jump_attack_area.get_overlapping_bodies():
		if not enemy.is_in_group("enemy"):
			continue

		if not enemy is CharacterBody2D:
			continue

		var knockback_direction: Vector2

		if not enemy.velocity.is_zero_approx():
			# Push opposite to the enemy's movement direction
			knockback_direction = -enemy.velocity.normalized()
		else:
			# Stationary enemies are pushed away from the player
			knockback_direction = (
				enemy.global_position - global_position
			).normalized()

		if enemy.has_method("apply_knockback"):
			enemy.apply_knockback(knockback_direction, 160.0)


func _process(delta: float) -> void:
	update_jump(delta)
	if is_oxygen_depleted:
		return

	# Ungültige oder bereits gelöschte Gegner entfernen
	for id in touching_enemies.keys():
		var touching_enemy = touching_enemies[id]

		if not is_instance_valid(touching_enemy):
			touching_enemies.erase(id)

	# Bedrohung = Summe der contact_damage-Werte aller berührenden Gegner.
	# Gegner ohne contact_damage zählen als 1.0, also identisch zu vorher.
	var threat: float = 0.0
	for touching_enemy in touching_enemies.values():
		if is_instance_valid(touching_enemy):
			var dmg = touching_enemy.get("contact_damage")
			threat += dmg if dmg != null else 1.0

	if threat >= 2.0:
		# Threat 2 = 5/s, 3 = 10/s, 4 = 20/s usw.
		var multiplier: float = pow(2.0, threat - 2.0)
		var loss_rate: float = oxygen_loss_base * multiplier

		oxygen -= loss_rate * delta
	else:
		# Bei weniger als 2 Bedrohung regeneriert sich Sauerstoff
		oxygen += oxygen_regen_rate * delta

	# Sauerstoff auf den erlaubten Bereich begrenzen
	oxygen = clampf(oxygen, 0.0, max_oxygen)

	# Anzeige aktualisieren
	oxygen_bar.value = oxygen

	# Spielende melden, wenn der Sauerstoff aufgebraucht ist
	if oxygen <= 0.0:
		is_oxygen_depleted = true
		oxygen_depleted.emit()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		touching_enemies[body.get_instance_id()] = body


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		touching_enemies.erase(body.get_instance_id())


func start_jump_attack() -> void:
	if is_jumping or is_oxygen_depleted:
		return

	if oxygen < jump_oxygen_cost:
		return

	oxygen -= jump_oxygen_cost
	oxygen_bar.value = oxygen

	is_jumping = true
	jump_timer = 0.0

	perform_jump_attack()

	if oxygen <= 0.0:
		is_oxygen_depleted = true
		oxygen_depleted.emit()


func register_touching_enemy(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return

	if not enemy.is_in_group("enemy"):
		return

	touching_enemies[enemy.get_instance_id()] = enemy


func unregister_touching_enemy(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return

	touching_enemies.erase(enemy.get_instance_id())


# Called by the spawner when an enemy's TouchHitbox emits "player_touched".
# The optional parameter works whether the signal sends no arguments or the enemy itself.
func _on_enemy_player_touched(enemy = null) -> void:
	if enemy is Node2D:
		register_touching_enemy(enemy)
