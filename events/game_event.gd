extends Node
class_name GameEvent
## Base class of the events of the game (the wave event now, others later). An event is switched on and off
## with start() / stop(). While it runs it may change the rules of the world (e.g. make everybody hostile) and show
## its own HUD, and it cleans up after itself in stop().

signal started
signal stopped

@export var event_id: StringName = &"event"
@export var display_name: String = "Event"

var is_active: bool = false


func _enter_tree() -> void:
	add_to_group("game_event")


func start() -> void:
	if is_active:
		return
	is_active = true
	_on_start()
	started.emit()


func stop() -> void:
	if not is_active:
		return
	is_active = false
	_on_stop()
	stopped.emit()


func toggle() -> void:
	if is_active:
		stop()
	else:
		start()


## Called when the event starts (set up its rules, HUD, spawning).
func _on_start() -> void:
	pass


## Called when the event ends (undo what _on_start did).
func _on_stop() -> void:
	pass


## The event with this id, or null.
static func find(tree: SceneTree, id: StringName) -> GameEvent:
	for node in tree.get_nodes_in_group("game_event"):
		var event := node as GameEvent
		if event != null and event.event_id == id:
			return event
	return null
