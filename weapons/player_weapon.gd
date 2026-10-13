extends Node
class_name PlayerWeapon
## Base class of the weapons the player carries in slots 2 and 3 (slot 1 is always the sword).
## A weapon is created when its pickup is collected and thrown away when its ammo runs out.
## Subclasses set their values in _init() and implement _shoot().

signal fired
## No ammo left: the owner should throw the weapon away.
signal emptied

@export var display_name: String = "Weapon"
## Hotbar slot (2 or 3). Only one weapon per slot, so only one of each type can be carried.
@export var slot: int = 2
@export var max_ammo: int = 1
## Seconds between two shots.
@export var fire_interval: float = 0.5
## true: hold the button to keep firing. false: one shot per click.
@export var automatic: bool = false
## The last shot is still visible for a moment before the weapon is thrown away.
@export var empty_toss_delay: float = 0.3
## LIGHT or HEAVY: decides how enemies killed by this weapon die (see WeaponClass).
@export var weapon_class: WeaponClass.Type = WeaponClass.Type.LIGHT

var icon: Texture2D
var ammo: int = 0
var owner_body: Node2D

# Player animations (side view) and how long the fire animation plays after a shot.
var anim_idle: StringName = &"idle_gun"
## Played while the player walks with this weapon (side view).
var anim_walk: StringName = &"walk_gun"
var anim_fire: StringName = &"attack_gun"
var fire_anim_speed: float = 1.0
var fire_anim_time: float = 0.15
var fire_anim_left: float = 0.0

# Where a shot leaves the weapon: in the side view (measured on the animation frames),
# and when aiming up / down (distance from the hand along the aim direction).
var muzzle_side: Vector2 = Vector2(7.0, 1.0)
var muzzle_vertical: float = 11.0

var _cooldown: float = 0.0
var _toss_pending: bool = false
var _toss_timer: float = 0.0


func setup(body: Node2D, bullets: int) -> void:
	owner_body = body
	ammo = mini(bullets, max_ammo)


## More ammo (another pickup or a shop purchase). False if the weapon is already full.
func add_ammo(amount: int) -> bool:
	if ammo >= max_ammo:
		return false

	ammo = mini(ammo + amount, max_ammo)
	_toss_pending = false  # picking something up right after the last shot saves the weapon
	return true


func is_full() -> bool:
	return ammo >= max_ammo


## Adds the weapon's own animations to the player's SpriteFrames (if it has any). Safe to call repeatedly.
func register_animations(_frames: SpriteFrames) -> void:
	pass


## Fires once if possible. `muzzle_pos` is global; `aim` is the unit firing direction.
func try_fire(aim: Vector2, muzzle_pos: Vector2, damage_multiplier: float = 1.0) -> bool:
	if _toss_pending or ammo <= 0 or _cooldown > 0.0:
		return false

	ammo -= 1
	_cooldown = fire_interval
	fire_anim_left = fire_anim_time

	_shoot(aim, muzzle_pos, damage_multiplier)
	fired.emit()

	if ammo <= 0:
		_toss_pending = true
		_toss_timer = empty_toss_delay
	return true


## Creates the projectile and effects. Implemented by the subclasses.
func _shoot(_aim: Vector2, _muzzle_pos: Vector2, _damage_multiplier: float) -> void:
	pass


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	fire_anim_left = maxf(fire_anim_left - delta, 0.0)

	if _toss_pending:
		_toss_timer -= delta
		if _toss_timer <= 0.0:
			_toss_pending = false
			emptied.emit()
