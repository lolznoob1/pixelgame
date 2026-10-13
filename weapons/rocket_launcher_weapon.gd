extends PlayerWeapon
class_name RocketLauncherWeapon
## The rocket launcher (slot 3). Every pickup gives ONE rocket, at most 5 can be carried.
## One rocket per click. The launcher is thrown away when the last rocket is gone.
##
## Explosion: everything within `inner_radius` takes `damage`; everything within `outer_radius`
## takes `damage * outer_damage_fraction` on top of that. The outer radius contains the inner one,
## so inside the inner radius the two stack (500 + 250 = 750 with the defaults), and between the
## two radii it is 250.

const ICON: Texture2D = preload("res://assets/weapons/rocket_launcher.png")
const PLAYER_SHEET: Texture2D = preload("res://assets/characters/player_rocket.png")
const PLAYER_WALK_SHEET: Texture2D = preload("res://assets/characters/player_walk_armed.png")
const ROCKET_SCENE: PackedScene = preload("res://weapons/rocket.tscn")

@export var damage: float = 500.0
## First damage radius (pixels).
@export var inner_radius: float = 50.0
## Second damage radius (pixels), deals extra damage inside the first one too.
@export var outer_radius: float = 80.0
@export_range(0.0, 1.0) var outer_damage_fraction: float = 0.5
@export var rocket_speed: float = 230.0
@export var rocket_lifetime: float = 1.6
## Push distance for enemies that survive the blast.
@export var knockback: float = 40.0


func _init() -> void:
	display_name = "Rocket Launcher"
	slot = 3
	max_ammo = 5
	fire_interval = 1.2
	automatic = false
	weapon_class = WeaponClass.Type.HEAVY
	icon = ICON
	anim_idle = &"idle_rocket"
	anim_walk = &"walk_rocket"
	anim_fire = &"fire_rocket"
	fire_anim_speed = 1.0
	fire_anim_time = 0.45
	muzzle_side = Vector2(8.0, 1.0)
	muzzle_vertical = 13.0


func register_animations(frames: SpriteFrames) -> void:
	SheetAnimations.add_row(frames, &"idle_rocket", PLAYER_SHEET, 0, 4, 5.0, true)
	SheetAnimations.add_row(frames, &"fire_rocket", PLAYER_SHEET, 1, 4, 10.0, false)
	SheetAnimations.add_row(frames, &"walk_rocket", PLAYER_WALK_SHEET, 1, 4, 8.0, true)


func _shoot(aim: Vector2, muzzle_pos: Vector2, damage_multiplier: float) -> void:
	RocketProjectile.launch(
		ROCKET_SCENE, get_tree(), muzzle_pos, aim, rocket_speed, rocket_lifetime,
		damage * damage_multiplier, inner_radius, outer_radius, outer_damage_fraction, knockback, owner_body, weapon_class
	)
	Fx.rocket_launch(get_tree(), muzzle_pos, aim)
