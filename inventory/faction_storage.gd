extends Area2D
class_name FactionStorage
## The place where the shared inventory of a faction can be reached (see FactionInventories). Members of the faction
## walk here to take what they need (hungry NPCs take food); the player may use it if the faction is friendly to them
## (press E). WHERE these objects stand on the map is not decided yet: put one anywhere (an Area2D with a
## CollisionShape2D child and this script) and set its faction.

@export var faction: Faction.Id = Faction.Id.CIVILIAN
@export var storage_name: String = "Storage"


func _enter_tree() -> void:
	add_to_group("food_source")
	add_to_group("faction_storage")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("set_interact_target"):
		body.call("set_interact_target", self)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("clear_interact_target"):
		body.call("clear_interact_target", self)


func inventory() -> Inventory:
	return FactionInventories.of(faction)


func prompt() -> String:
	return "[E]  %s  (%s)" % [storage_name, Faction.display_name(faction)]


func interact(actor: Node) -> void:
	if not actor.is_in_group("player"):
		return
	if Relations.faction_to_player(faction) != Relation.Level.FRIENDLY:
		actor.call("_show_hint", "%s won't let you use their storage" % Faction.display_name(faction))
		return
	StorageWindow.open_for(self, actor)


# --------------------------------------------------
# NPCS (see NpcTasks): members take food from here
# --------------------------------------------------

func food_spot() -> Vector2:
	return global_position


func _first_food() -> ItemData:
	var stored: Inventory = inventory()
	for item_id in stored.ids():
		var item: ItemData = ItemDatabase.get_item(item_id)
		if item != null and item.effect == ItemData.Effect.FOOD:
			return item
	return null


func can_serve_food(npc: NpcCharacter) -> bool:
	return Relations.faction_of(npc) == faction and _first_food() != null


func serve_food(npc: NpcCharacter) -> bool:
	var food: ItemData = _first_food()
	if food == null:
		return false
	return inventory().transfer_to(npc.inventory, food.id, 1) > 0
