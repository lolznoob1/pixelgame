extends Node2D
## Sword attack. Child of the player. The player calls try_attack() when it swings,
## so animation, cooldown and damage can't get out of sync.
##
## Hit area: a sector (pie slice) in front of the player.
## attack_arc_degrees = 180 -> half circle in the direction the player is facing.

@export var attack_damage: float = 100.0
## Reach in pixels, measured from the player's center to the enemy's center.
@export var attack_range: float = 20.0
@export_range(0.0, 360.0) var attack_arc_degrees: float = 180.0
@export var attack_cooldown: float = 0.8
## Enemies that survive a hit are pushed this far (pixels). 0 = none.
@export var knockback_distance: float = 40.0
## The sword is a light weapon: enemies it kills die in a spray of blood and leave a corpse.
@export var weapon_class: WeaponClass.Type = WeaponClass.Type.LIGHT

@export_group("Placeholder visual")
## Flashes the hit area for a moment so you can see what the attack covers.
@export var show_arc: bool = true
@export var arc_color: Color = Color(1.0, 1.0, 1.0, 0.45)
@export var arc_fade_time: float = 0.15

var player: Node2D

var _cooldown_left: float = 0.0
var _flash_left: float = 0.0


func _ready() -> void:
	player = get_parent() as Node2D

	if player == null:
		push_error("Attack must be a child of the player.")


func _process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)

	if _flash_left > 0.0:
		_flash_left -= delta
		queue_redraw()


func can_attack() -> bool:
	return _cooldown_left <= 0.0 and is_instance_valid(player)


## `facing`: direction the arc points to. `damage_multiplier`: from power-ups.
## Returns false while on cooldown (nothing happens then).
func try_attack(facing: Vector2, damage_multiplier: float = 1.0) -> bool:
	if not can_attack():
		return false

	_cooldown_left = attack_cooldown

	if facing.is_zero_approx():
		facing = Vector2.RIGHT
	facing = facing.normalized()

	var origin: Vector2 = player.global_position
	var targets: Array[Node2D] = HitDetection.targets_in_arc(
		get_tree(), &"npc", origin, facing, attack_range, attack_arc_degrees
	)

	for enemy in targets:
		if not enemy.has_method("take_hit"):
			continue

		var direction: Vector2 = (enemy.global_position - origin).normalized()
		if direction.is_zero_approx():
			direction = facing

		enemy.take_hit(HitInfo.create(
			attack_damage * damage_multiplier * _melee_factor(), player, direction, knockback_distance, true, weapon_class
		))

	if show_arc:
		rotation = facing.angle()
		_flash_left = arc_fade_time
		queue_redraw()

	return true


func _draw() -> void:
	if not show_arc or _flash_left <= 0.0 or attack_arc_degrees < 1.0:
		return

	var color: Color = arc_color
	color.a *= clampf(_flash_left / maxf(arc_fade_time, 0.001), 0.0, 1.0)

	# Pie slice centered on +X (the node itself is rotated toward the facing direction).
	var half_arc: float = deg_to_rad(attack_arc_degrees) * 0.5
	var points := PackedVector2Array([Vector2.ZERO])
	var steps: int = 24
	for i in range(steps + 1):
		var angle: float = -half_arc + 2.0 * half_arc * float(i) / float(steps)
		points.append(Vector2.from_angle(angle) * attack_range)

	draw_colored_polygon(points, color)


# Starving halves the sword's damage (see NeedsRules).
func _melee_factor() -> float:
	if player != null and player.has_method("melee_factor"):
		return float(player.call("melee_factor"))
	return 1.0
