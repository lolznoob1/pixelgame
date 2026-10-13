extends PlayerWeapon
class_name Ak47Weapon
## The AK-47 (slot 2): one pool of bullets (max 300), no reload, hold the button for full auto.
## Every pickup adds 30 bullets; the rifle is thrown away when the last bullet is fired.

const BULLET_SCENE: PackedScene = preload("res://weapons/bullet.tscn")
const ICON: Texture2D = preload("res://assets/weapons/ak47.png")
const PLAYER_WALK_SHEET: Texture2D = preload("res://assets/characters/player_walk_armed.png")

@export var bullet_damage: float = 12.0
@export var bullet_speed: float = 420.0
@export var bullet_lifetime: float = 1.1
@export var bullet_knockback: float = 6.0
@export var spread_degrees: float = 2.5


func _init() -> void:
	display_name = "AK-47"
	slot = 2
	max_ammo = 300
	fire_interval = 0.1  # 10 shots per second
	automatic = true
	weapon_class = WeaponClass.Type.LIGHT
	icon = ICON
	anim_idle = &"idle_gun"
	anim_walk = &"walk_gun"
	anim_fire = &"attack_gun"
	fire_anim_speed = 2.0
	fire_anim_time = 0.15
	muzzle_side = Vector2(7.0, 1.0)
	muzzle_vertical = 11.0


# idle_gun and attack_gun are in the player's scene; the walk cycle comes from its own sheet (row 0).
func register_animations(frames: SpriteFrames) -> void:
	SheetAnimations.add_row(frames, &"walk_gun", PLAYER_WALK_SHEET, 0, 4, 8.0, true)


func _shoot(aim: Vector2, muzzle_pos: Vector2, damage_multiplier: float) -> void:
	var direction: Vector2 = Vector2.from_angle(aim.angle() + deg_to_rad(randf_range(-spread_degrees, spread_degrees)))

	PlayerBullet.launch(
		BULLET_SCENE, get_tree(), muzzle_pos, direction,
		bullet_speed, bullet_damage * damage_multiplier, bullet_knockback, bullet_lifetime, owner_body, weapon_class
	)
	Fx.muzzle_flash(get_tree(), muzzle_pos, direction)
	Fx.shell_eject(get_tree(), muzzle_pos - direction * 3.0, direction)
