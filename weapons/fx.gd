extends RefCounted
class_name Fx
## Small one-shot visual effects (particles + sprites). Everything cleans itself up.

const MUZZLE_FLASH: Texture2D = preload("res://assets/weapons/muzzle_flash.png")


## Adds `node` to the current scene at a global position and frees it after `lifetime`.
## (Public wrapper of _place for the other effect classes.)
static func place_node(tree: SceneTree, node: Node2D, global_pos: Vector2, lifetime: float) -> void:
	_place(tree, node, global_pos, lifetime)


static func _place(tree: SceneTree, node: Node2D, global_pos: Vector2, lifetime: float) -> void:
	var scene: Node = tree.current_scene if tree != null else null
	if scene == null:
		node.free()
		return

	var scene_2d := scene as Node2D
	node.position = scene_2d.to_local(global_pos) if scene_2d != null else global_pos
	node.z_index = 20
	scene.add_child.call_deferred(node)  # deferred: often called from physics callbacks
	tree.create_timer(lifetime).timeout.connect(node.queue_free)


static func _burst(
	amount: int, lifetime: float, direction: Vector2, spread_degrees: float,
	speed_min: float, speed_max: float, color: Color,
	size_min: float, size_max: float, gravity: Vector2 = Vector2.ZERO, damping: float = 0.0
) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.direction = direction
	p.spread = spread_degrees
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.gravity = gravity
	p.damping_min = damping
	p.damping_max = damping
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max

	# Fade out over the lifetime.
	var fade := Gradient.new()
	fade.set_color(0, color)
	fade.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = fade

	p.emitting = true
	return p


## Flash + sparks at the gun's muzzle. `direction` is the firing direction.
static func muzzle_flash(tree: SceneTree, pos: Vector2, direction: Vector2) -> void:
	var holder := Node2D.new()
	holder.rotation = direction.angle()

	var flash := Sprite2D.new()
	flash.texture = MUZZLE_FLASH
	flash.position = Vector2(5.0, 0.0)
	holder.add_child(flash)

	holder.add_child(_burst(5, 0.12, Vector2.RIGHT, 28.0, 60.0, 150.0, Color(1.0, 0.8, 0.3), 1.2, 2.2))

	_place(tree, holder, pos, 0.14)
	# The flash sprite itself only lives for a moment.
	if is_instance_valid(flash):
		tree.create_timer(0.045).timeout.connect(flash.queue_free)


## Brass casing that pops out to the side and falls.
static func shell_eject(tree: SceneTree, pos: Vector2, firing_direction: Vector2) -> void:
	var side := Vector2(-firing_direction.y, firing_direction.x)  # perpendicular
	var eject: Vector2 = (side + Vector2(0.0, -1.2)).normalized()
	var shell := _burst(1, 0.45, eject, 25.0, 45.0, 75.0, Color(0.9, 0.7, 0.25), 1.6, 1.6, Vector2(0.0, 320.0))
	_place(tree, shell, pos, 0.55)


## Sparks where a bullet lands. `back_direction` points away from the surface.
static func impact(tree: SceneTree, pos: Vector2, back_direction: Vector2, color: Color) -> void:
	var sparks := _burst(7, 0.28, back_direction, 55.0, 35.0, 110.0, color, 1.2, 2.4, Vector2.ZERO, 40.0)
	_place(tree, sparks, pos, 0.32)


## Glass shards and water droplets when a bottle bursts.
static func glass_shatter(tree: SceneTree, pos: Vector2) -> void:
	var holder := Node2D.new()
	holder.add_child(_burst(10, 0.45, Vector2.UP, 180.0, 40.0, 130.0, Color(0.8, 0.95, 1.0, 0.95), 1.4, 2.4, Vector2(0.0, 260.0), 10.0))
	holder.add_child(_burst(8, 0.35, Vector2.UP, 180.0, 25.0, 90.0, Color(0.35, 0.65, 0.95, 0.9), 1.2, 2.0, Vector2(0.0, 200.0)))
	_place(tree, holder, pos, 0.6)


## Burst + expanding ring at the point where the teleport lands. `radius` is the damage radius.
static func teleport_blast(tree: SceneTree, pos: Vector2, radius: float) -> void:
	var holder := Node2D.new()
	holder.add_child(_burst(16, 0.3, Vector2.RIGHT, 180.0, radius * 1.5, radius * 4.0, Color(0.6, 0.9, 1.0), 1.5, 2.5, Vector2.ZERO, 25.0))
	var ring := RingFlash.new()
	ring.max_radius = radius
	holder.add_child(ring)
	_place(tree, holder, pos, 0.4)


## Superhero take-off: the air under the character decompresses (two expanding pressure rings and
## dust blown outward), the ground cracks. `radius` is the jump's knockback zone.
static func jump_burst(tree: SceneTree, pos: Vector2, radius: float) -> void:
	var holder := Node2D.new()

	var pressure := RingFlash.new()
	pressure.max_radius = radius * 1.8
	pressure.duration = 0.3
	pressure.line_width = 2.0
	pressure.color = Color(1.0, 1.0, 1.0, 0.85)
	holder.add_child(pressure)

	var wave := RingFlash.new()
	wave.max_radius = radius * 2.6
	wave.duration = 0.4
	wave.delay = 0.06
	wave.line_width = 1.0
	wave.fill = false
	wave.color = Color(0.85, 0.95, 1.0, 0.6)
	holder.add_child(wave)

	# Dust blown outward along the ground, and a puff pushed up.
	holder.add_child(_burst(14, 0.45, Vector2.RIGHT, 180.0, radius * 2.0, radius * 5.0, Color(0.85, 0.82, 0.78, 0.8), 1.8, 3.5, Vector2.ZERO, 40.0))
	holder.add_child(_burst(8, 0.5, Vector2.UP, 25.0, 25.0, 55.0, Color(0.9, 0.88, 0.85, 0.7), 1.5, 3.0, Vector2(0.0, 60.0), 20.0))
	_place(tree, holder, pos, 0.7)

	GroundCracks.spawn(tree, pos, radius)


## Small dust puff when the jump ends.
static func jump_land(tree: SceneTree, pos: Vector2, radius: float) -> void:
	var holder := Node2D.new()
	holder.add_child(_burst(8, 0.35, Vector2.RIGHT, 180.0, radius, radius * 3.0, Color(0.85, 0.82, 0.78, 0.7), 1.5, 3.0, Vector2.ZERO, 40.0))
	_place(tree, holder, pos, 0.45)


## Particles sucked into the center of the character as it disappears into the teleport.
static func teleport_suck(tree: SceneTree, pos: Vector2, radius: float = 10.0) -> void:
	var particles := _burst(14, 0.2, Vector2.ZERO, 0.0, 0.0, 0.0, Color(0.6, 0.9, 1.0), 1.5, 2.5)
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = radius
	particles.radial_accel_min = -radius * 40.0   # negative = toward the center
	particles.radial_accel_max = -radius * 50.0
	var holder := Node2D.new()
	holder.add_child(particles)
	_place(tree, holder, pos, 0.3)


## Fireball, shockwave rings for both damage radii, sparks, smoke, debris and a scorch mark.
static func explosion(tree: SceneTree, pos: Vector2, inner_radius: float, outer_radius: float) -> void:
	var holder := Node2D.new()

	var blast := ExplosionBlast.new()
	blast.fireball_radius = inner_radius
	holder.add_child(blast)

	# Two shockwave rings: the first damage radius (fast) and the second one (slower).
	var inner_ring := RingFlash.new()
	inner_ring.max_radius = inner_radius
	inner_ring.duration = 0.22
	inner_ring.line_width = 3.0
	inner_ring.fill = false
	inner_ring.color = Color(1.0, 0.95, 0.75, 0.9)
	holder.add_child(inner_ring)

	var outer_ring := RingFlash.new()
	outer_ring.max_radius = outer_radius
	outer_ring.duration = 0.4
	outer_ring.delay = 0.05
	outer_ring.line_width = 2.0
	outer_ring.fill = false
	outer_ring.color = Color(1.0, 0.75, 0.4, 0.7)
	holder.add_child(outer_ring)

	holder.add_child(_burst(26, 0.6, Vector2.RIGHT, 180.0, inner_radius, inner_radius * 4.2, Color(1.0, 0.7, 0.25), 1.5, 3.0, Vector2.ZERO, 30.0))
	holder.add_child(_burst(14, 1.0, Vector2.UP, 70.0, 10.0, 40.0, Color(0.25, 0.22, 0.24, 0.8), 4.0, 7.0, Vector2(0.0, -25.0), 15.0))
	holder.add_child(_burst(12, 0.8, Vector2.UP, 90.0, 60.0, 160.0, Color(0.45, 0.32, 0.22), 2.0, 3.5, Vector2(0.0, 420.0), 5.0))
	_place(tree, holder, pos, 1.3)

	ScorchMark.spawn(tree, pos, inner_radius * 0.8)


## Backblast behind the launcher, a flash and smoke at the muzzle.
static func rocket_launch(tree: SceneTree, pos: Vector2, aim: Vector2) -> void:
	var holder := Node2D.new()
	holder.add_child(_burst(12, 0.35, -aim, 35.0, 60.0, 150.0, Color(1.0, 0.75, 0.3), 1.5, 3.0))
	holder.add_child(_burst(10, 0.7, -aim, 50.0, 15.0, 50.0, Color(0.7, 0.7, 0.72, 0.8), 3.0, 5.5, Vector2.ZERO, 25.0))
	holder.add_child(_burst(6, 0.2, aim, 25.0, 40.0, 110.0, Color(1.0, 0.9, 0.5), 1.5, 2.5))
	_place(tree, holder, pos, 0.8)


## Goo chunks, droplets and a dark mist when a character explodes. `intensity` scales the amount.
static func goo_burst(tree: SceneTree, pos: Vector2, intensity: float = 1.0) -> void:
	var holder := Node2D.new()
	var chunks: int = maxi(8, int(roundf(18.0 * intensity)))
	holder.add_child(_burst(chunks, 0.75, Vector2.UP, 180.0, 40.0, 150.0, Color(0.8, 0.1, 0.15), 2.0, 4.5, Vector2(0.0, 380.0), 8.0))
	holder.add_child(_burst(chunks + 12, 0.55, Vector2.RIGHT, 180.0, 20.0, 115.0, Color(0.95, 0.25, 0.3), 1.2, 2.2, Vector2(0.0, 250.0), 20.0))
	holder.add_child(_burst(8, 0.9, Vector2.UP, 60.0, 8.0, 30.0, Color(0.5, 0.05, 0.1, 0.8), 4.0, 7.0, Vector2(0.0, 40.0), 10.0))
	_place(tree, holder, pos, 1.0)


## A fine mist of blood: many tiny droplets, mostly in the direction of the hit. `direction` zero = all around.
static func blood_spray(tree: SceneTree, pos: Vector2, direction: Vector2, intensity: float = 1.0) -> void:
	var holder := Node2D.new()
	var aimed: bool = not direction.is_zero_approx()
	var dir: Vector2 = direction.normalized() if aimed else Vector2.UP
	var spread: float = 55.0 if aimed else 180.0
	var amount: int = maxi(10, int(roundf(44.0 * intensity)))
	holder.add_child(_burst(amount, 0.65, dir, spread, 60.0, 230.0, Color(0.93, 0.16, 0.20), 1.0, 1.8, Vector2(0.0, 220.0), 25.0))
	holder.add_child(_burst(amount, 0.60, dir, spread + 25.0, 40.0, 190.0, Color(0.55, 0.05, 0.10), 1.0, 1.8, Vector2(0.0, 240.0), 25.0))
	holder.add_child(_burst(maxi(6, int(float(amount) / 3.0)), 0.5, Vector2.RIGHT, 180.0, 15.0, 90.0, Color(0.45, 0.15, 0.12), 1.0, 1.6, Vector2(0.0, 200.0), 20.0))
	holder.add_child(_burst(5, 0.7, dir, 40.0, 40.0, 120.0, Color(0.75, 0.08, 0.12), 2.2, 3.6, Vector2(0.0, 320.0), 10.0))
	_place(tree, holder, pos, 0.9)


## Little dust puffs behind a sprinting player.
static func sprint_dust(tree: SceneTree, pos: Vector2, move_direction: Vector2) -> void:
	var dust := _burst(2, 0.35, -move_direction, 35.0, 8.0, 22.0, Color(0.82, 0.8, 0.76, 0.8), 1.8, 3.2, Vector2.ZERO, 30.0)
	_place(tree, dust, pos, 0.4)
