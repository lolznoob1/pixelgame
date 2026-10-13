extends StaticBody2D

@export var Background: Sprite2D
@export var wall_thickness := 40.0

## The playable area in global coordinates (filled in _ready).
var world_rect := Rect2()


func _ready() -> void:
	add_to_group("world_bounds")

	if Background == null or Background.texture == null:
		push_error("Assign a Sprite2D with a texture to 'Background'.")
		return

	# Sprite's rect in its own local space (handles centered + offset)
	var local_rect: Rect2 = Background.get_rect()

	# Convert to global space (handles position, scale, and parent transforms)
	var top_left: Vector2 = Background.to_global(local_rect.position)
	var bottom_right: Vector2 = Background.to_global(local_rect.end)
	var global_rect := Rect2(top_left, bottom_right - top_left).abs()
	world_rect = global_rect

	# Convert to this body's local space, since the collision shapes are its children
	var local_tl: Vector2 = to_local(global_rect.position)
	var local_br: Vector2 = to_local(global_rect.end)
	var rect := Rect2(local_tl, local_br - local_tl).abs()

	build_walls(rect)


## Returns the nearest point inside the world (used e.g. for the teleport).
func clamp_to_world(pos: Vector2, margin: float = 0.0) -> Vector2:
	if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		return pos
	var inner: Rect2 = world_rect.grow(-margin)
	return pos.clamp(inner.position, inner.end)


func build_walls(rect: Rect2) -> void:
	var t := wall_thickness
	var center := rect.get_center()

	# Top
	create_wall(Vector2(center.x, rect.position.y - t / 2), Vector2(rect.size.x, t))
	# Bottom
	create_wall(Vector2(center.x, rect.end.y + t / 2), Vector2(rect.size.x, t))
	# Left
	create_wall(Vector2(rect.position.x - t / 2, center.y), Vector2(t, rect.size.y))
	# Right
	create_wall(Vector2(rect.end.x + t / 2, center.y), Vector2(t, rect.size.y))


func create_wall(wall_position: Vector2, wall_size: Vector2) -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()

	shape.size = wall_size
	collision.shape = shape
	collision.position = wall_position

	add_child(collision)
