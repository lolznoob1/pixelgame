extends RefCounted
class_name UpgradeCatalog
## The stats the player can upgrade with coins between waves.
## To add one: add an entry here and handle its id in player.gd `_apply_upgrade()`.
## Cost of level n (starting at 0) = cost * growth^n, rounded.
## An entry with "requires": an ability id only shows up once the player has unlocked that ability.

const UPGRADES: Array[Dictionary] = [
	{"id": &"max_health", "group": "Stats", "name": "Max Health", "desc": "+20 maximum health (and heals 20)", "max": 5, "cost": 4, "growth": 1.5},
	{"id": &"max_stamina", "group": "Stats", "name": "Max Stamina", "desc": "+20 maximum stamina", "max": 5, "cost": 4, "growth": 1.5},
	{"id": &"health_regen", "group": "Stats", "name": "Health Regeneration", "desc": "+1 health per second", "max": 5, "cost": 5, "growth": 1.5, "requires": PlayerAbilities.HEALTH_REGEN},
	{"id": &"stamina_regen", "group": "Stats", "name": "Stamina Regeneration", "desc": "+2 stamina per second", "max": 5, "cost": 4, "growth": 1.5},
	{"id": &"move_speed", "group": "Stats", "name": "Move Speed", "desc": "+8% walking speed", "max": 5, "cost": 5, "growth": 1.5},
]


static func get_def(id: StringName) -> Dictionary:
	for def in UPGRADES:
		if def["id"] == id:
			return def
	return {}


static func cost_for(def: Dictionary, level: int) -> int:
	return maxi(1, roundi(float(def["cost"]) * pow(float(def["growth"]), float(level))))
