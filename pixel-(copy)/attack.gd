
extends Node2D

@export var attack_damage: float = 100.0
@export var attack_range: float = 20.0
@export var attack_cooldown: float = 0.8

var can_attack: bool = true
var player: Node2D


func _ready() -> void:
	player = get_parent() as Node2D

	if player == null:
		push_error("Attack must be a child of the player.")


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("attack") and can_attack:
		perform_attack()


func perform_attack() -> void:
	if not is_instance_valid(player):
		return

	can_attack = false

	var hit_enemies: Array[Node] = []

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue

		if not enemy is Node2D:
			continue

		var distance := player.global_position.distance_to(
			enemy.global_position
		)

		if distance <= attack_range and enemy.has_method("take_damage"):
			if enemy not in hit_enemies:
				hit_enemies.append(enemy)
				enemy.take_damage(attack_damage)

	await get_tree().create_timer(attack_cooldown).timeout

	can_attack = true
