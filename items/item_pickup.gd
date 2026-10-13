extends Area2D
class_name ItemPickup
## An item lying in the world. The player collects it by touching it.

signal collected(item: ItemData)

@export var item: ItemData:
	set(value):
		item = value
		_refresh_visual()

## Seconds until it disappears (0 = never).
@export var lifetime: float = 15.0
## Blinks during the last seconds of its lifetime.
@export var blink_time: float = 3.0
## Can't be picked up right after spawning (hurt drops land on the player).
@export var pickup_delay: float = 0.5
@export var magnet_range: float = 36.0
@export var magnet_speed: float = 110.0
## Set by the spawner: where the drop pops out to. (-INF = stay where spawned.)
var launch_target: Vector2 = Vector2(-INF, -INF)

@onready var sprite: Sprite2D = $Sprite2D

var _age: float = 0.0
var _bob_time: float = 0.0


func _ready() -> void:
	add_to_group("pickup")
	_bob_time = randf() * TAU
	_refresh_visual()

	if is_finite(launch_target.x):
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "global_position", launch_target, 0.3)


func _refresh_visual() -> void:
	if sprite == null or item == null:
		return
	sprite.texture = item.texture
	sprite.modulate = item.tint


func _physics_process(delta: float) -> void:
	_age += delta

	# Lifetime + blink.
	if lifetime > 0.0:
		var remaining: float = lifetime - _age
		if remaining <= 0.0:
			queue_free()
			return
		if remaining < blink_time:
			sprite.visible = int(_age * 8.0) % 2 == 0

	# Little hover animation (sprite only, not the collision).
	_bob_time += delta * 4.0
	sprite.position.y = sin(_bob_time) * 1.5

	if _age < pickup_delay or item == null:
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and player.has_method("can_collect_item") and player.can_collect_item(item):
		var distance: float = global_position.distance_to(player.global_position)
		if distance < magnet_range:
			global_position = global_position.move_toward(player.global_position, magnet_speed * delta)

	# Polling instead of body_entered: works even if the player was already
	# standing inside the pickup when the delay ran out.
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("collect_item"):
			if body.collect_item(item):
				collected.emit(item)
				queue_free()
				return
