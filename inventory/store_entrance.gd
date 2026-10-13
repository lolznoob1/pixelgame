extends Area2D
class_name StoreEntrance
## The entrance of a store (the two gas stations). Stand in the zone and press E to shop; hungry NPCs walk here to
## buy food. The store sells what is in `stock`; the prices come from ItemEconomy, so they can change at any time
## (an event, the developer menu ...). Food and drinks are "need" items (ItemData.Category.NEED).

@export var store_name: String = "Gas Station"
## What the store sells: item id -> how many it has (-1 = unlimited).
@export var stock: Dictionary = {&"sandwich": -1, &"beer": -1}

## Money the store has earned from NPCs and the player.
var earnings: int = 0


func _enter_tree() -> void:
	add_to_group("food_source")
	add_to_group("store")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # bodies (the player)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("set_interact_target"):
		body.call("set_interact_target", self)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("clear_interact_target"):
		body.call("clear_interact_target", self)


# --------------------------------------------------
# THE PLAYER (called by the player when E is pressed)
# --------------------------------------------------

func prompt() -> String:
	return "[E]  %s" % store_name


func interact(actor: Node) -> void:
	if actor.is_in_group("player"):
		StoreWindow.open_for(self, actor)


# --------------------------------------------------
# STOCK
# --------------------------------------------------

## The items on sale (the ones that have stock left).
func items_for_sale() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item_id in stock:
		var item: ItemData = ItemDatabase.get_item(item_id)
		if item != null:
			result.append(item)
	return result


## -1 = unlimited.
func stock_of(item_id: StringName) -> int:
	return int(stock.get(item_id, 0))


func has_stock(item_id: StringName) -> bool:
	var amount: int = stock_of(item_id)
	return amount < 0 or amount > 0


## One item was sold: the stock goes down (unlimited stock never does) and the store earns the price.
func sold(item: ItemData, price: int) -> void:
	var amount: int = stock_of(item.id)
	if amount > 0:
		stock[item.id] = amount - 1
	earnings += price


# --------------------------------------------------
# NPCS (see NpcTasks)
# --------------------------------------------------

func food_spot() -> Vector2:
	return global_position


func _cheapest_food_for(npc: NpcCharacter) -> ItemData:
	var best: ItemData = null
	var best_price: int = 0
	var coins: int = npc.inventory.count(&"coin")
	for item in items_for_sale():
		if item.effect != ItemData.Effect.FOOD or not has_stock(item.id):
			continue
		var price: int = ItemEconomy.price_of(item)
		if price <= coins and (best == null or price < best_price):
			best = item
			best_price = price
	return best


func can_serve_food(npc: NpcCharacter) -> bool:
	return _cheapest_food_for(npc) != null


## An NPC buys the cheapest food it can afford. It eats it by itself when it is hungry enough.
func serve_food(npc: NpcCharacter) -> bool:
	var item: ItemData = _cheapest_food_for(npc)
	if item == null:
		return false
	var price: int = ItemEconomy.price_of(item)
	npc.inventory.remove(&"coin", price)
	npc.inventory.add(item.id, 1)
	sold(item, price)
	return true
