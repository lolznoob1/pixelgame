extends Node2D
class_name TossedWeapon
## Purely visual: the empty gun is thrown away, tumbles, bounces once and fades out.

const GRAVITY: float = 520.0

var _velocity: Vector2 = Vector2.ZERO
var _height: float = 4.0
var _vertical_speed: float = 150.0
var _spin: float = 0.0
var _landed_time: float = 0.0
var _landed: bool = false

var _sprite: Sprite2D


static func launch(tree: SceneTree, from: Vector2, direction: Vector2, texture: Texture2D) -> void:
	if tree == null or tree.current_scene == null or texture == null:
		return

	var toss := TossedWeapon.new()
	toss._sprite = Sprite2D.new()
	toss._sprite.texture = texture
	toss.add_child(toss._sprite)

	var angle: float = direction.angle() + randf_range(-0.5, 0.5)
	toss._velocity = Vector2.from_angle(angle) * randf_range(85.0, 120.0)
	toss._spin = randf_range(10.0, 15.0) * (1.0 if randf() < 0.5 else -1.0)
	toss.z_index = 15

	var container: Node = tree.current_scene
	var container_2d := container as Node2D
	toss.position = container_2d.to_local(from) if container_2d != null else from
	container.add_child.call_deferred(toss)


func _physics_process(delta: float) -> void:
	if _landed:
		_landed_time += delta
		# Lie there for a moment, then fade out.
		if _landed_time > 1.2:
			modulate.a = maxf(0.0, 1.0 - (_landed_time - 1.2) / 0.8)
			if modulate.a <= 0.0:
				queue_free()
		return

	position += _velocity * delta

	# Fake height: the sprite is lifted above its shadow while it flies.
	_vertical_speed -= GRAVITY * delta
	_height += _vertical_speed * delta

	if _height <= 0.0:
		_height = 0.0
		if absf(_vertical_speed) > 45.0:
			_vertical_speed = -_vertical_speed * 0.4   # bounce
			_velocity *= 0.55
			_spin *= 0.5
		else:
			_landed = true
			_velocity = Vector2.ZERO

	_sprite.position.y = -_height
	_sprite.rotation += _spin * delta
	queue_redraw()


func _draw() -> void:
	# Flat shadow on the ground; shrinks as the gun goes up.
	var shrink: float = clampf(1.0 - _height / 40.0, 0.4, 1.0)
	draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 6.0 * shrink, Color(0.0, 0.0, 0.0, 0.35))
