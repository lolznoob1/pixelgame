extends RefCounted
class_name Faction
## Every NPC belongs to one faction. UNIQUE is special: unique NPCs are always neutral to every faction,
## and only the player can change their relation, one by one (see Relations).

enum Id {
	EMERGENCY, POLICE, MILITARY, CIVILIAN, ANIMAL, CULT, CHURCH,
	GANG1, GANG2, GANG3, DEMON, HOLY, ALIEN, UNIQUE
}

const NAMES: Dictionary = {
	Id.EMERGENCY: "Emergency",
	Id.POLICE: "Police",
	Id.MILITARY: "Military",
	Id.CIVILIAN: "Civilian",
	Id.ANIMAL: "Animal",
	Id.CULT: "Cult",
	Id.CHURCH: "Church",
	Id.GANG1: "Gang 1",
	Id.GANG2: "Gang 2",
	Id.GANG3: "Gang 3",
	Id.DEMON: "Demon",
	Id.HOLY: "Holy",
	Id.ALIEN: "Alien",
	Id.UNIQUE: "Unique",
}


static func display_name(id: Id) -> String:
	return String(NAMES.get(id, "?"))


## All factions a normal NPC can belong to (everything except UNIQUE).
static func regular() -> Array[Id]:
	var result: Array[Id] = []
	for id in Id.values():
		if id != Id.UNIQUE:
			result.append(id)
	return result
