extends Node
class_name NpcManager
## Central crowd service for all NpcCharacters.
##
## Replaces the old per-enemy `get_nodes_in_group()` scans (O(n^2) every frame)
## with ONE pass per physics frame:
##   1. A spatial hash grid, so separation only looks at nearby enemies.
##   2. Encirclement slots, assigned per target by bearing (stable, no criss-crossing).
##
## The spawner creates this node automatically. Enemies work without it too
## (they just skip separation/encirclement), so a lone enemy scene still runs with F6.

## Enemies closer than this push each other apart. Also the grid cell size.
@export var separation_radius: float = 42.0
## How often encirclement slots are re-assigned.
@export var slot_update_interval: float = 0.25
## Enemies are clamped into this rect (set by the spawner). Size zero = no clamping.
@export var world_rect: Rect2 = Rect2()

# Sort key = angle bucket * INDEX_RANGE + index, so a native sort() orders by angle.
const ANGLE_STEPS: float = 1000000.0
const INDEX_RANGE: int = 65536

var _list: Array[NpcCharacter] = []
var _positions: PackedVector2Array = PackedVector2Array()
var _cells: Dictionary = {}  # Vector2i -> Array[int] (indices into _list)
var _inv_cell: float = 1.0 / 42.0
var _slot_timer: float = 0.0
var _zones: Array[HouseColliders] = []


static func find(from: Node) -> NpcManager:
	return from.get_tree().get_first_node_in_group("npc_manager") as NpcManager


func _enter_tree() -> void:
	add_to_group("npc_manager")


func _ready() -> void:
	# Run before the enemies so they see this frame's grid.
	process_physics_priority = -100
	for node in get_tree().get_nodes_in_group(HouseColliders.GROUP):
		var zone := node as HouseColliders
		if zone != null:
			_zones.append(zone)


func _physics_process(delta: float) -> void:
	_rebuild_grid()

	_slot_timer -= delta
	if _slot_timer <= 0.0:
		_slot_timer = slot_update_interval
		_assign_slots()


# --------------------------------------------------
# PUBLIC API
# --------------------------------------------------

func enemy_count() -> int:
	return _list.size()


## All living NPCs within `radius` of an NPC (not including itself), from the spatial grid: cheap.
func find_nearby(npc: NpcCharacter, radius: float) -> Array[NpcCharacter]:
	var result: Array[NpcCharacter] = []
	var pos: Vector2 = npc.global_position
	var reach: int = ceili(radius / maxf(separation_radius, 1.0))
	var center: Vector2i = _cell_of(pos)
	var radius_squared: float = radius * radius
	for dx in range(-reach, reach + 1):
		for dy in range(-reach, reach + 1):
			var bucket: Variant = _cells.get(Vector2i(center.x + dx, center.y + dy))
			if bucket == null:
				continue
			for i: int in bucket:
				var other: NpcCharacter = _list[i]
				if other != npc and pos.distance_squared_to(_positions[i]) <= radius_squared:
					result.append(other)
	return result


## Unit vector pointing away from crowded neighbours, or ZERO if there is none.
func get_separation(enemy: NpcCharacter) -> Vector2:
	var radius: float = maxf(separation_radius, 1.0)
	var pos: Vector2 = enemy.global_position
	var cell: Vector2i = _cell_of(pos)
	var push := Vector2.ZERO

	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var bucket: Variant = _cells.get(Vector2i(cell.x + dx, cell.y + dy))
			if bucket == null:
				continue
			for i: int in bucket:
				if _list[i] == enemy:
					continue
				var offset: Vector2 = pos - _positions[i]
				var dist_sq: float = offset.length_squared()
				if dist_sq < 0.000001 or dist_sq >= radius * radius:
					continue
				var dist: float = sqrt(dist_sq)
				push += offset / dist * (1.0 - dist / radius)

	if push.length_squared() > 0.001:
		return push.normalized()
	return Vector2.ZERO


## True if the point is inside a house, building, container, silo or tree (out of bounds).
func is_blocked(pos: Vector2) -> bool:
	for zone in _zones:
		if is_instance_valid(zone) and zone.contains_point(pos):
			return true
	return false


## Keeps a position inside the world. A position INSIDE a house is out of bounds and
## becomes the zone's respawn point (0, 0).
func clamp_to_world(pos: Vector2) -> Vector2:
	if is_blocked(pos):
		return HouseColliders.safe_respawn(get_tree())
	if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		return pos
	return pos.clamp(world_rect.position, world_rect.end)


# --------------------------------------------------
# SPATIAL GRID
# --------------------------------------------------

func _cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x * _inv_cell), floori(pos.y * _inv_cell))


func _rebuild_grid() -> void:
	_inv_cell = 1.0 / maxf(separation_radius, 1.0)
	_list.clear()
	_positions.clear()
	_cells.clear()

	for node: Node in get_tree().get_nodes_in_group("npc"):
		var enemy := node as NpcCharacter
		if enemy == null or enemy.dead:
			continue

		var index: int = _list.size()
		var pos: Vector2 = enemy.global_position
		_list.append(enemy)
		_positions.append(pos)

		var key: Vector2i = _cell_of(pos)
		var bucket: Variant = _cells.get(key)
		if bucket == null:
			_cells[key] = [index]
		else:
			bucket.append(index)


# --------------------------------------------------
# ENCIRCLEMENT SLOTS
# --------------------------------------------------

func _assign_slots() -> void:
	# Group all enemies that want a slot by the target they chase.
	var groups: Dictionary = {}  # target instance id -> Array[NpcCharacter]
	for enemy in _list:
		if not enemy.ai.wants_slot():
			continue
		var key: int = enemy.target.get_instance_id()
		if not groups.has(key):
			groups[key] = []
		groups[key].append(enemy)

	for key: int in groups:
		_assign_ring(groups[key])


# Spreads the chasers evenly around their target. Enemies are ordered by their
# current bearing, and the ring is rotated to match that order as closely as
# possible, so enemies take the slot nearest to where they already are.
func _assign_ring(chasers: Array) -> void:
	var count: int = chasers.size()
	if count == 0 or count >= INDEX_RANGE:
		return

	var center: Vector2 = (chasers[0] as NpcCharacter).target.global_position
	var angles := PackedFloat32Array()
	var keys := PackedInt64Array()
	angles.resize(count)
	keys.resize(count)

	for i in count:
		var enemy: NpcCharacter = chasers[i]
		var angle: float = (enemy.global_position - center).angle()
		angles[i] = angle
		keys[i] = int((angle + PI) / TAU * ANGLE_STEPS) * INDEX_RANGE + i

	keys.sort()  # native sort, orders by angle

	# Circular mean of (bearing - ideal slot angle) = best ring rotation.
	var sum_cos: float = 0.0
	var sum_sin: float = 0.0
	for rank in count:
		var index: int = keys[rank] % INDEX_RANGE
		var residual: float = angles[index] - TAU * float(rank) / float(count)
		sum_cos += cos(residual)
		sum_sin += sin(residual)
	var base: float = atan2(sum_sin, sum_cos)

	for rank in count:
		var index: int = keys[rank] % INDEX_RANGE
		var enemy: NpcCharacter = chasers[index]
		enemy.ai.slot_angle = base + TAU * float(rank) / float(count)
