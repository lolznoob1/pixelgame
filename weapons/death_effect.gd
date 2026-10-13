extends RefCounted
class_name DeathEffect
## What happens when a character dies. It depends on the CLASS of the weapon that landed the killing hit:
##   HEAVY (rocket launcher): the character explodes into red goo: the explosion animation, flying chunks,
##       a dark mist and a puddle (GooSplat).
##   LIGHT (sword, AK-47): the character is shot down: it falls over, sprays a fine mist of blood in the direction
##       of the hit and collapses into a bloody corpse that stays on the ground for a while (DeathBurst + Fx.blood_spray
##       + BloodSpray).
## Used by the enemies and by the player.

## How long a corpse stays before it fades (seconds).
const CORPSE_TIME: float = 12.0


## The one call to use. `pos`: global position of the character's center. `size_scale`: how big the character is.
## `intensity`: 1 = normal; more means a bigger, wetter death (higher rarity). `direction`: where the hit came
## from the attacker toward the victim (zero if unknown).
static func play_for(
	tree: SceneTree, pos: Vector2, weapon_class: WeaponClass.Type,
	heavy_sheet: Texture2D, light_sheet: Texture2D,
	size_scale: float = 1.0, intensity: float = 1.0, direction: Vector2 = Vector2.ZERO
) -> void:
	if weapon_class == WeaponClass.Type.HEAVY:
		play_heavy(tree, pos, heavy_sheet, size_scale, intensity)
	else:
		play_light(tree, pos, light_sheet, size_scale, intensity, direction)


static func play_heavy(tree: SceneTree, pos: Vector2, sheet: Texture2D, size_scale: float = 1.0, intensity: float = 1.0) -> void:
	DeathBurst.play_at(tree, pos, sheet, size_scale, false, 0.0, 20, 14.0)
	Fx.goo_burst(tree, pos, intensity)
	GooSplat.spawn(tree, pos + Vector2(0.0, 6.0 * size_scale), 18.0 * size_scale * (0.8 + 0.2 * intensity))


static func play_light(
	tree: SceneTree, pos: Vector2, sheet: Texture2D, size_scale: float = 1.0,
	intensity: float = 1.0, direction: Vector2 = Vector2.ZERO
) -> void:
	# The sheet falls toward +x; mirror it so the body falls in the direction of the hit.
	DeathBurst.play_at(tree, pos, sheet, size_scale, direction.x < 0.0, CORPSE_TIME, -3, 12.0)
	Fx.blood_spray(tree, pos, direction, intensity)
	BloodSpray.spawn(tree, pos + Vector2(0.0, 5.0 * size_scale), 34.0 * size_scale * (0.85 + 0.15 * intensity), direction)
