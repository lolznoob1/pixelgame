
extends Area2D
class_name EnemyTouchHitbox

signal player_touched(player: Node2D)

@export var touch_cooldown: float = 0.5

var _can_touch: bool = true
var _current_player: Node2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	if not _can_touch:
		return

	_current_player = body
	player_touched.emit(body)

	if body.has_method("register_touching_enemy"):
		var enemy := get_parent() as Node2D
		if enemy != null:
			body.register_touching_enemy(enemy)

	_can_touch = false
	_reset_touch_cooldown()


func _on_body_exited(body: Node2D) -> void:
	if body != _current_player:
		return

	if body.has_method("unregister_touching_enemy"):
		var enemy := get_parent() as Node2D
		if enemy != null:
			body.unregister_touching_enemy(enemy)

	_current_player = null


func _reset_touch_cooldown() -> void:
	await get_tree().create_timer(touch_cooldown).timeout

	if is_inside_tree():
		_can_touch = true
