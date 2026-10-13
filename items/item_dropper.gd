extends Node
class_name ItemDropper
## Component that drops items at its parent's position.
## Enemies and the player create one automatically (see NpcCharacter / player.gd);
## you can also add it by hand as a child "ItemDropper" and fill in the tables.

@export var death_drops: DropTable
@export var hurt_drops: DropTable
## Minimum time between two hurt drops, so rapid hits can't flood the map.
@export var hurt_drop_cooldown: float = 0.5
## How far items are scattered around the entity.
@export var scatter_distance: float = 24.0

var _next_hurt_drop_msec: int = 0


func drop_on_death() -> void:
	_drop(death_drops)


func drop_on_hurt() -> void:
	var now: int = Time.get_ticks_msec()
	if now < _next_hurt_drop_msec:
		return
	_next_hurt_drop_msec = now + int(hurt_drop_cooldown * 1000.0)
	_drop(hurt_drops)


func _drop(table: DropTable) -> void:
	if table == null:
		return

	var entity := get_parent() as Node2D
	if entity == null or not is_inside_tree():
		return

	for item in table.roll(entity):
		ItemSpawner.spawn(item, entity.global_position, get_tree(), scatter_distance)
