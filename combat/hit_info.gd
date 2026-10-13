extends RefCounted
class_name HitInfo
## Everything a target needs to know about one hit.
## Anything that can be hit implements:  func take_hit(hit: HitInfo) -> bool

var damage: float = 0.0
## Who dealt the hit (player or an enemy). May be freed by the time it is read.
var source: Node2D
## Unit vector pointing from the attacker toward the target.
var direction: Vector2 = Vector2.ZERO
## Push distance in pixels (0 = no knockback).
var knockback_distance: float = 0.0
## true: the target is stunned (hurt state, no control for a moment). false: it only takes damage.
var stun: bool = true
## The class of the weapon that dealt the hit. It decides how an enemy dies (see WeaponClass).
var weapon_class: WeaponClass.Type = WeaponClass.Type.LIGHT


static func create(
	hit_damage: float,
	hit_source: Node2D,
	hit_direction: Vector2,
	hit_knockback: float = 0.0,
	hit_stun: bool = true,
	hit_class: WeaponClass.Type = WeaponClass.Type.LIGHT
) -> HitInfo:
	var info := HitInfo.new()
	info.damage = hit_damage
	info.source = hit_source
	info.direction = hit_direction
	info.knockback_distance = hit_knockback
	info.stun = hit_stun
	info.weapon_class = hit_class
	return info
