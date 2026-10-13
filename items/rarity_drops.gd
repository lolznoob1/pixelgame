extends RefCounted
class_name RarityDrops
## The death drops of an enemy depend on its RARITY (not on its type). One DropTable per rarity:
##   common     one pickup at most: coin 50 %, AK-47 10 %, health pack 5 %, stamina drink 5 %, nothing 30 %
##   uncommon   one pickup at most: coin 50 %, AK-47 20 %, health pack 5 %, stamina drink 5 %, nothing 20 %
##   rare       2 coins, plus independent chances; at most 5 pickups
##   legendary  3 coins, plus independent chances; at most 7 pickups
##   mythical   10 coins, plus independent chances; at most 15 pickups
## Edit the .tres files in items/drops/ (drops_common.tres ... drops_mythical.tres) to change them.

const PATHS: Array[String] = [
	"res://items/drops/drops_common.tres",
	"res://items/drops/drops_uncommon.tres",
	"res://items/drops/drops_rare.tres",
	"res://items/drops/drops_legendary.tres",
	"res://items/drops/drops_mythical.tres",
]

static var _cache: Array = [null, null, null, null, null]


static func table_for(tier: int) -> DropTable:
	var index: int = Rarity.clamp_tier(tier)
	if _cache[index] == null:
		_cache[index] = load(PATHS[index])
	return _cache[index] as DropTable
