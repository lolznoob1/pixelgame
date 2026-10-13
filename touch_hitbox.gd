extends Area2D
class_name NpcTouchHitbox
## The NPC's contact zone. This is the single source of truth for
## "which NPCs currently touch the player". (It only hurts if the NPC is hostile, see NpcCharacter.can_hurt_player.)

signal player_touched(player: Node2D)

## Minimum time between two player_touched signals (presence tracking is NOT rate-limited).
@export var touch_cooldown: float = 0.5

var _next_signal_msec: int = 0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	var enemy := get_parent() as Node2D
	if enemy != null and body.has_method("register_touching_enemy"):
		body.register_touching_enemy(enemy)

	# No await/timer: nothing can resume on a freed enemy.
	var now: int = Time.get_ticks_msec()
	if now >= _next_signal_msec:
		_next_signal_msec = now + int(touch_cooldown * 1000.0)
		player_touched.emit(body)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	var enemy := get_parent() as Node2D
	if enemy != null and body.has_method("unregister_touching_enemy"):
		body.unregister_touching_enemy(enemy)
