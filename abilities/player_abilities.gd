extends RefCounted
class_name PlayerAbilities
## Abilities the player has to unlock first. How they get unlocked is not decided yet; the unlock itself is one
## call:  player.abilities.unlock(PlayerAbilities.HEALTH_REGEN)  (the developer menu has switches for testing).
##
##   HEALTH_REGEN          health regenerates over time (without it health only comes back from items).
##   STAMINA_REGEN_ACTIVE  stamina keeps regenerating while sprinting and jumping (without it it only regenerates
##                         while walking or standing still).

const HEALTH_REGEN: StringName = &"health_regen"
const STAMINA_REGEN_ACTIVE: StringName = &"stamina_regen_active"

const NAMES: Dictionary = {
	HEALTH_REGEN: "Health regeneration",
	STAMINA_REGEN_ACTIVE: "Stamina regeneration while sprinting and jumping",
}

signal changed(ability: StringName, unlocked: bool)

var _unlocked: Dictionary = {}


func has(ability: StringName) -> bool:
	return bool(_unlocked.get(ability, false))


func unlock(ability: StringName) -> void:
	if has(ability):
		return
	_unlocked[ability] = true
	changed.emit(ability, true)


func lock(ability: StringName) -> void:
	if not has(ability):
		return
	_unlocked.erase(ability)
	changed.emit(ability, false)


static func all_ids() -> Array:
	return NAMES.keys()
