extends StaticBody2D
class_name HouseColliders
## Solid collision for things drawn on the background: houses, buildings, containers, silos, trees.
## The main scene has several of these nodes (Houses, Buildings, Containers, Silos, Trees); each child
## CollisionShape2D (RectangleShape2D or CircleShape2D) is one obstacle. Move or resize them in the editor.
##
## Anything whose CENTER ends up INSIDE one of these shapes (teleport ability, ghost knockback through a
## wall, a bad spawn) counts as out of bounds and is sent to the respawn point (0, 0 by default; if that
## spot is blocked, the nearest free spot is used).
## Limitation: rectangles must be axis-aligned (no rotation); circles must be scaled uniformly.

const GROUP: StringName = &"out_of_bounds_zones"
## Cell size of the lookup grid, and the largest `margin` that contains_point() supports.
const CELL_SIZE: float = 64.0
const MAX_MARGIN: float = 16.0

@export var respawn_point: Vector2 = Vector2.ZERO

var _rects: Array[Rect2] = []
var _circles: Array[Vector3] = []  # x, y = center, z = radius
# Grid cell -> shape ids. A rectangle i is stored as i, a circle j as -(j + 1).
var _grid: Dictionary = {}


## Any of the collider nodes (they all share the respawn point).
static func find(tree: SceneTree) -> HouseColliders:
	return tree.get_first_node_in_group(GROUP) as HouseColliders


## True if `point` (grown by `margin`, max 16 px) is inside ANY obstacle of ANY collider node.
static func point_blocked(tree: SceneTree, point: Vector2, margin: float = 0.0) -> bool:
	for node in tree.get_nodes_in_group(GROUP):
		var zone := node as HouseColliders
		if zone != null and zone.contains_point(point, margin):
			return true
	return false


## The respawn point, or the nearest free spot around it if it is blocked.
static func safe_respawn(tree: SceneTree) -> Vector2:
	var start: Vector2 = Vector2.ZERO
	var zone: HouseColliders = find(tree)
	if zone != null:
		start = zone.respawn_point

	if not point_blocked(tree, start, 12.0):
		return start

	for ring in range(1, 60):
		var radius: float = float(ring) * 8.0
		for step in 16:
			var candidate: Vector2 = start + Vector2.from_angle(TAU * float(step) / 16.0) * radius
			if not point_blocked(tree, candidate, 12.0):
				return candidate
	return start


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	for child in get_children():
		var shape_node := child as CollisionShape2D
		if shape_node == null or shape_node.disabled:
			continue

		var center: Vector2 = shape_node.global_position

		var rect_shape := shape_node.shape as RectangleShape2D
		if rect_shape != null:
			var size: Vector2 = rect_shape.size * shape_node.global_scale.abs()
			var rect := Rect2(center - size * 0.5, size)
			_rects.append(rect)
			_register(rect.grow(MAX_MARGIN), _rects.size() - 1)
			continue

		var circle_shape := shape_node.shape as CircleShape2D
		if circle_shape != null:
			var radius: float = circle_shape.radius * shape_node.global_scale.x
			_circles.append(Vector3(center.x, center.y, radius))
			var box := Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
			_register(box.grow(MAX_MARGIN), -_circles.size())
			continue

		push_warning("HouseColliders: '%s' is neither a RectangleShape2D nor a CircleShape2D and is ignored for out-of-bounds checks." % child.name)


# Stores a shape id in every grid cell its (grown) bounding box touches.
func _register(area: Rect2, id: int) -> void:
	var first: Vector2i = _cell_of(area.position)
	var last: Vector2i = _cell_of(area.end)
	for cell_x in range(first.x, last.x + 1):
		for cell_y in range(first.y, last.y + 1):
			var key := Vector2i(cell_x, cell_y)
			if not _grid.has(key):
				_grid[key] = []
			_grid[key].append(id)


func _cell_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL_SIZE), floori(point.y / CELL_SIZE))


## `margin` grows every shape, e.g. to test whether a body of a given radius would overlap it.
func contains_point(point: Vector2, margin: float = 0.0) -> bool:
	var ids: Variant = _grid.get(_cell_of(point))
	if ids == null:
		return false

	var grown: float = minf(margin, MAX_MARGIN)
	for id: int in ids:
		if id >= 0:
			if _rects[id].grow(grown).has_point(point):
				return true
		else:
			var circle: Vector3 = _circles[-id - 1]
			var reach: float = circle.z + grown
			if Vector2(circle.x, circle.y).distance_squared_to(point) <= reach * reach:
				return true
	return false
