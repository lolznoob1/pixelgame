extends Resource
class_name ItemData
## Describes one kind of item. Create a new .tres of this type to add an item.
## `category` is informational (UI / sorting); `effect` decides what happens on pickup.

enum Category { PICKUP, POWERUP, WEAPON, NEED }  ## NEED = food and drinks (hunger, thirst)
enum Effect {
	COIN,    ## Added to the inventory (amount = how many).
	STAMINA, ## Restores `amount` stamina instantly.
	SPEED,   ## +amount speed (0.5 = +50%) for `duration` seconds.
	DAMAGE,  ## +amount attack damage (1.0 = +100%) for `duration` seconds.
	SHIELD,  ## No damage taken for `duration` seconds.
	AK47,    ## First pickup equips the rifle with `amount` bullets; every further one adds `amount` bullets (max 300).
	HEALTH,  ## Restores `amount` health instantly.
	ROCKET,  ## Rocket launcher (slot 3): the first pickup equips it, every pickup adds `amount` rockets (max 5).
	ABILITY, ## Ability core: permanently shortens the cooldowns of the bottle and the teleport by `amount` (0.1 = 10 %), and resets them now.
	FOOD,    ## A need item: goes into the inventory, eating it restores `amount` hunger (see ItemEconomy.restore_of).
	DRINK,   ## A need item: goes into the inventory, drinking it restores `amount` thirst.
}

@export var id: StringName = &"item"
@export var display_name: String = "Item"
@export var category: Category = Category.PICKUP
@export var effect: Effect = Effect.COIN
@export var amount: float = 1.0
## Only used by timed power-ups. Picking the same power-up again refreshes the timer.
@export var duration: float = 0.0
## Price in coins in a store. Read it through ItemEconomy.price_of(), which can change it while the game runs.
@export var base_price: int = 1
@export var texture: Texture2D
@export var tint: Color = Color.WHITE


func is_timed() -> bool:
	return effect == Effect.SPEED or effect == Effect.DAMAGE or effect == Effect.SHIELD
