extends RefCounted
class_name NeedsRules
## The numbers of the needs system in one place.

## Hunger at 0: health lost per second (player and NPCs) ...
const STARVE_DAMAGE_PER_SECOND: float = 5.0
## ... and the "hungry" debuff: movement speed and melee attack damage are multiplied by this.
const HUNGRY_SPEED_FACTOR: float = 0.5
const HUNGRY_MELEE_FACTOR: float = 0.5
## The player's thirst runs down this many units per minute (NPCs have no thirst).
const PLAYER_THIRST_PER_MINUTE: float = 10.0
## An NPC eats when its hunger is below this and it carries food.
const NPC_EAT_BELOW: float = 40.0
