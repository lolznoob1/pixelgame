extends RefCounted
class_name WeaponClass
## Every weapon belongs to a class. The class of the weapon that lands the killing hit decides how an enemy dies:
##   LIGHT  sword, AK-47: the enemy is shot down, sprays fine blood and leaves a bloody corpse.
##   HEAVY  rocket launcher: the enemy explodes into red goo.
## New weapons just pick a class (PlayerWeapon.weapon_class); abilities and enemy attacks count as LIGHT.

enum Type { LIGHT, HEAVY }


static func display_name(type: Type) -> String:
	return "Heavy" if type == Type.HEAVY else "Light"
