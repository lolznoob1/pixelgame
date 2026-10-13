extends CharacterBody2D
class_name NpcCharacter
## Body of every NPC: health, movement, knockback, animation, and its identity: faction, needs (hunger),
## inventory, goals and mood. The NpcAI child decides what to do; this script carries it out.
## NPCs of the wave event are `is_event_npc`: always hostile to the player, they drop by rarity (RarityDrops).
## Normal NPCs drop what they carry.

signal attack_requested(target: Node2D)
signal died(enemy: NpcCharacter)

## Optional. If assigned, its values override the exports below.
## If empty, the enemy uses the exports, so existing scenes keep working.
@export var stats: NpcStats

@export_group("Stats")
@export var max_health: float = 100.0
@export var detection_range: float = 700.0
## Distance (center to center) at which the enemy switches to ATTACK.
## Keep it close to the touch hitbox reach, otherwise the enemy stops
## before it can touch anything.
@export var attack_range: float = 18.0
@export_range(0.0, 1.0) var flee_health_ratio: float = 0.25
@export var hurt_speed_multiplier: float = 0.5
## How long the hurt state (slow + hurt animation) lasts.
@export var hurt_duration: float = 0.3

@export_group("Attack")
## Telegraph time: the hit is checked this long AFTER the attack starts,
## so the player can dodge. The sprite tints red meanwhile.
@export var attack_windup: float = 0.25
## Width of the hit area in front of the enemy (360 = full circle).
@export_range(0.0, 360.0) var attack_arc_degrees: float = 120.0
## Hit reach in pixels. 0 = attack_range + 6.
@export var attack_reach: float = 0.0
@export var attack_knockback: float = 30.0

@export_group("Rarity")
## Every step doubles health, armor and attack damage (see Rarity). The spawner sets this.
@export var rarity: Rarity.Tier = Rarity.Tier.COMMON
@export var show_rarity_label: bool = true

@export_group("Knockback")
@export var knockback_speed: float = 500.0
## After a knockback the enemy is a "ghost" for this long: no collisions,
## cannot hurt the player.
@export var knockback_immunity_duration: float = 2.0

@onready var ai: NpcAI = $NpcAI
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var touch_hitbox: Area2D = get_node_or_null("TouchHitbox")

# Written by the AI behaviors, applied in _physics_process.
var desired_direction: Vector2 = Vector2.ZERO
var desired_speed: float = 0.0

var health: float
var target: Node2D
var hurt: bool = false
var dead: bool = false

# Filled from NpcStats in _ready() (defaults match the old behavior).
var contact_damage: float = 1.0
var attack_damage: float = 5.0
var armor: float = 0.0
## Behaviors may set this to make the sprite face something other than the walking direction.
var look_direction: Vector2 = Vector2.ZERO

# Ranged attack (filled from NpcStats)
var projectile_scene: PackedScene
var projectile_speed: float = 140.0
var projectile_lifetime: float = 2.0
var projectile_knockback: float = 0.0
var projectile_stun: bool = false
var death_sheet_heavy: Texture2D
var death_sheet_light: Texture2D
# The class and direction of the last hit decide how the enemy dies (see WeaponClass / DeathEffect).
var _last_hit_class: WeaponClass.Type = WeaponClass.Type.LIGHT
var _last_hit_direction: Vector2 = Vector2.ZERO
var throw_anim: StringName = &"throw"
var throw_release_frame: int = 2
var _throw_anim_playing: bool = false
var speed_multiplier: float = 1.0
var knockback_resistance: float = 0.0
var idle_anim: StringName = &"idle"
var walk_anim: StringName = &"walk"
var hurt_anim: StringName = &"hurt"
var death_anim: StringName = &"death"

var dropper: ItemDropper

# --- identity, needs, inventory, mood ---
var faction: Faction.Id = Faction.Id.CIVILIAN
## true when somebody (the population) chose the faction: the stats' faction is then not applied.
var faction_assigned: bool = false
## Not empty = a unique NPC (own relation with the player, neutral to all factions).
var unique_id: StringName = &""
var npc_type: NpcType.Type = NpcType.Type.MEDIUM
var hunger: Need = Need.new()
## false: this NPC never gets hungry (the wave event can switch hunger off for its NPCs).
var hunger_enabled: bool = true
var inventory: Inventory = Inventory.new()
var goals: Array[NpcGoal] = []
var happiness: Happiness.State = Happiness.State.HAPPY
var unfulfilled_goals: int = 0
## true for NPCs spawned by the wave event.
var is_event_npc: bool = false
var home_position: Vector2 = Vector2.ZERO
var npc_detection_range: float = 160.0
## Somebody who attacked this NPC: it fights back for a while, whatever their relation is.
var grudge_target: Node2D
var _grudge_left: float = 0.0
## Seconds before it tries a task (like getting food) again after one failed or was done.
var task_cooldown: float = 0.0
var _goal_timer: float = 0.0
var _start_hunger_min: float = 60.0
var _start_coins: Vector2i = Vector2i.ZERO
var _start_food: Vector2i = Vector2i.ZERO
var _hit_by_player: bool = false
var _hostile_when_hit: bool = false
const MAX_DROPPED_ITEMS: int = 12

const WINDUP_TINT: Color = Color(1.0, 0.45, 0.45)

## 8-direction turn-around sprites (optional, from NpcStats).
var direction_sheet: DirectionalSheet
var _facing: DirectionalFacing = DirectionalFacing.new()
var _attack_windup_left: float = 0.0
# Unstick: enemies steer straight at the player, so houses can block them.
var _stuck_time: float = 0.0
var _sidestep_left: float = 0.0
var _sidestep_sign: float = 1.0
var _sidestep_length: float = 0.7
var _last_sidestep_msec: int = -100000
var _attack_target: Node2D
var _attack_direction: Vector2 = Vector2.RIGHT
var _base_sprite_scale: Vector2 = Vector2.ONE
var _base_collision_layer: int
var _base_collision_mask: int

var _hurt_time_left: float = 0.0
var _ghost_time_left: float = 0.0
var _knockback_direction: Vector2 = Vector2.ZERO
var _knockback_distance_remaining: float = 0.0


func _ready() -> void:
	add_to_group("npc")
	_base_sprite_scale = sprite.scale
	_base_collision_layer = collision_layer
	_base_collision_mask = collision_mask

	_apply_stats()
	_apply_rarity()
	_setup_identity()
	_setup_dropper()
	_setup_rarity_visuals()
	health = max_health

	if direction_sheet != null:
		DirectionalFacing.build_animations(sprite.sprite_frames, direction_sheet)
	sprite.animation_finished.connect(_on_animation_finished)
	_play_animation(idle_anim)


# Every enemy gets an ItemDropper. Tables come from the NpcStats; a hand-placed
# "ItemDropper" child in the scene takes priority for any table it already has.
func _setup_dropper() -> void:
	dropper = get_node_or_null("ItemDropper") as ItemDropper
	if dropper == null:
		dropper = ItemDropper.new()
		dropper.name = "ItemDropper"
		add_child(dropper)

	# Event NPCs drop by their rarity (RarityDrops); a table set in the NpcStats still overrides it. Normal NPCs
	# drop what they carry instead (see _drop_inventory).
	if dropper.death_drops == null:
		if stats != null and stats.death_drops != null:
			dropper.death_drops = stats.death_drops
		elif is_event_npc:
			dropper.death_drops = RarityDrops.table_for(rarity)
	if dropper.hurt_drops == null and stats != null:
		dropper.hurt_drops = stats.hurt_drops


# Hunger, starting inventory, goals and the starting relation of a unique NPC.
func _setup_identity() -> void:
	home_position = global_position
	hunger.rate_per_minute = NpcType.hunger_per_minute(npc_type, int(rarity))
	hunger.value = 100.0 if is_event_npc else randf_range(_start_hunger_min, 100.0)

	if not is_event_npc:
		inventory.add(&"coin", randi_range(mini(_start_coins.x, _start_coins.y), maxi(_start_coins.x, _start_coins.y)))
		var food: ItemData = ItemDatabase.first_with_effect(ItemData.Effect.FOOD)
		if food != null:
			inventory.add(food.id, randi_range(mini(_start_food.x, _start_food.y), maxi(_start_food.x, _start_food.y)))

	goals = stats.goals if (stats != null and not stats.goals.is_empty()) else NpcGoal.default_set()
	_goal_timer = randf()  # not every NPC evaluates in the same frame

	if stats != null and unique_id != &"" and not Relations.unique_points.has(unique_id):
		Relations.set_unique_points(unique_id, stats.unique_start_points)


# --------------------------------------------------
# NEEDS, GOALS, MOOD
# --------------------------------------------------

func _tick_needs(delta: float) -> void:
	if hunger_enabled:
		hunger.tick(delta)
	if hunger.is_empty():
		health -= NeedsRules.STARVE_DAMAGE_PER_SECOND * delta  # starving (no armor, no hurt reaction)
		if health <= 0.0:
			health = 0.0
			_die()
			return
	elif hunger.value < NeedsRules.NPC_EAT_BELOW:
		_try_eat()

	task_cooldown = maxf(task_cooldown - delta, 0.0)
	if _grudge_left > 0.0:
		_grudge_left -= delta
		if _grudge_left <= 0.0:
			grudge_target = null

	_goal_timer -= delta
	if _goal_timer <= 0.0:
		_goal_timer = 1.0
		_evaluate_goals()


# Counts the unfulfilled goals: the mood follows from it (see Happiness).
func _evaluate_goals() -> void:
	var unfulfilled: int = 0
	for goal in goals:
		if goal != null and not goal.is_fulfilled(self):
			unfulfilled += 1
	unfulfilled_goals = unfulfilled
	happiness = Happiness.from_unfulfilled_goals(unfulfilled)


func _try_eat() -> void:
	for item_id in inventory.ids():
		var item: ItemData = ItemDatabase.get_item(item_id)
		if item != null and item.effect == ItemData.Effect.FOOD:
			inventory.remove(item_id, 1)
			hunger.restore(ItemEconomy.restore_of(item))
			return


## How many food items it carries.
func food_count() -> int:
	var count: int = 0
	for item_id in inventory.ids():
		var item: ItemData = ItemDatabase.get_item(item_id)
		if item != null and item.effect == ItemData.Effect.FOOD:
			count += inventory.count(item_id)
	return count


## Gives one food item to another NPC (sharing). Returns true if it had one.
func give_food_to(other: NpcCharacter) -> bool:
	for item_id in inventory.ids():
		var item: ItemData = ItemDatabase.get_item(item_id)
		if item != null and item.effect == ItemData.Effect.FOOD:
			return inventory.transfer_to(other.inventory, item_id, 1) > 0
	return false


## Hungry, nothing to eat and not tried recently: time to look for food.
func wants_food() -> bool:
	return not is_event_npc and hunger.value < 45.0 and food_count() == 0 and task_cooldown <= 0.0


func task_done() -> void:
	task_cooldown = 5.0


func task_failed() -> void:
	task_cooldown = 30.0


# --------------------------------------------------
# RELATIONS
# --------------------------------------------------

func is_hostile_to_player() -> bool:
	return Relations.npc_to_player(self) == Relation.Level.HOSTILE


func is_hostile_to(other: Node2D) -> bool:
	return Relations.between(self, other) == Relation.Level.HOSTILE


## True while somebody who attacked this NPC is still remembered (it fights back).
func has_grudge_against(other: Node2D) -> bool:
	return _grudge_left > 0.0 and is_instance_valid(grudge_target) and grudge_target == other


## How far it notices enemies, by mood: unhappy NPCs are edgy, depressed ones hardly react.
func aggression_scale() -> float:
	match happiness:
		Happiness.State.UNHAPPY:
			return 1.3
		Happiness.State.DEPRESSED:
			return 0.5
	return 1.0


## Is there somebody with this relation to me within `radius`? (The player counts too.)
func has_nearby(radius: float, level: Relation.Level) -> bool:
	var player_node := get_tree().get_first_node_in_group("player") as Node2D
	if player_node != null and global_position.distance_to(player_node.global_position) <= radius \
			and Relations.npc_to_player(self) == level:
		return true
	if is_instance_valid(ai.manager):
		for other in ai.manager.find_nearby(self, radius):
			if not other.dead and Relations.between(self, other) == level:
				return true
	return false


# --------------------------------------------------
# DROPS OF A NORMAL NPC
# --------------------------------------------------

# A normal NPC drops everything it carries (coins, food ...), at most MAX_DROPPED_ITEMS pickups.
func _drop_inventory() -> void:
	var dropped: int = 0
	for item_id in inventory.ids():
		var item: ItemData = ItemDatabase.get_item(item_id)
		if item == null:
			continue
		for i in inventory.count(item_id):
			if dropped >= MAX_DROPPED_ITEMS:
				return
			ItemSpawner.spawn(item, global_position, get_tree(), 24.0)
			dropped += 1


# Every rarity step doubles health, armor and attack damage.
# contact_damage is deliberately NOT scaled: the player's health drain grows
# exponentially with it, so doubling it per tier would be instantly lethal.
func _apply_rarity() -> void:
	rarity = Rarity.clamp_tier(rarity) as Rarity.Tier
	var factor: float = Rarity.multiplier(rarity)
	max_health *= factor
	armor *= factor
	attack_damage *= factor


func _setup_rarity_visuals() -> void:
	sprite.self_modulate = Rarity.sprite_tint(rarity)

	# The faction above the NPC (green friendly, gray neutral, red hostile).
	var faction_badge := FactionBadge.new()
	faction_badge.name = "FactionBadge"
	faction_badge.position = Vector2(0.0, sprite.position.y - 8.0 * absf(sprite.scale.y) - 8.0)
	add_child(faction_badge)
	faction_badge.setup(self)

	# Ordinary common NPCs walking around town get no rarity label and no glow (event enemies and rarer NPCs do).
	if not is_event_npc and rarity == Rarity.Tier.COMMON:
		return

	# Colored light on the ground under the enemy, in the color of its rarity.
	var glow := RarityGlow.new()
	glow.name = "RarityGlow"
	add_child(glow)
	glow.setup(rarity, sprite.position + Vector2(0.0, 5.0 * absf(sprite.scale.y)), absf(sprite.scale.x))

	# Always created, so the developer menu can switch the labels on and off while playing.
	var badge := RarityBadge.new()
	badge.name = "RarityBadge"
	badge.enabled_by_owner = show_rarity_label
	badge.position = Vector2(0.0, sprite.position.y - 8.0 * absf(sprite.scale.y) - 2.0)
	add_child(badge)
	badge.setup(rarity)


func _begin_throw_animation() -> void:
	if not _has_animation(throw_anim):
		return

	sprite.flip_h = _attack_direction.x < 0.0

	# Play the animation so that the release frame starts exactly when the windup ends.
	var frames_per_second: float = sprite.sprite_frames.get_animation_speed(throw_anim)
	var speed_scale: float = 1.0
	if _attack_windup_left > 0.0 and throw_release_frame > 0 and frames_per_second > 0.0:
		speed_scale = (float(throw_release_frame) / _attack_windup_left) / frames_per_second

	_throw_anim_playing = true
	sprite.play(throw_anim, speed_scale)


func _release_projectile(victim: Node2D) -> void:
	var direction: Vector2 = global_position.direction_to(victim.global_position)
	NpcProjectile.launch(
		projectile_scene, get_tree(),
		global_position + direction * 6.0, direction,
		projectile_speed, attack_damage, projectile_knockback, projectile_lifetime, self, projectile_stun
	)


func _apply_stats() -> void:
	if stats == null:
		return

	max_health = stats.max_health
	if not faction_assigned:
		faction = stats.faction
	unique_id = stats.unique_id
	npc_type = stats.npc_type
	npc_detection_range = stats.npc_detection_range
	_start_hunger_min = stats.start_hunger_min
	_start_coins = stats.start_coins
	_start_food = stats.start_food
	contact_damage = stats.contact_damage
	attack_damage = stats.attack_damage
	armor = stats.armor
	attack_windup = stats.attack_windup
	projectile_scene = stats.projectile_scene
	projectile_speed = stats.projectile_speed
	projectile_lifetime = stats.projectile_lifetime
	projectile_knockback = stats.projectile_knockback
	projectile_stun = stats.projectile_stun
	direction_sheet = stats.direction_sheet
	death_sheet_heavy = stats.death_sheet_heavy
	death_sheet_light = stats.death_sheet_light
	throw_anim = stats.throw_animation
	throw_release_frame = stats.throw_release_frame
	if stats.approach == NpcStats.Approach.KEEP_DISTANCE:
		attack_range = stats.max_distance
	ai.configure(stats)
	speed_multiplier = stats.speed_multiplier
	knockback_resistance = stats.knockback_resistance

	idle_anim = stats.idle_animation
	walk_anim = stats.walk_animation
	hurt_anim = stats.hurt_animation
	death_anim = stats.death_animation

	if stats.sprite_frames != null:
		if _has_any_frames(stats.sprite_frames):
			sprite.sprite_frames = stats.sprite_frames
		else:
			# An empty SpriteFrames would make the enemy invisible.
			push_warning("NpcStats '%s' has an empty SpriteFrames; keeping the scene's frames." % stats.display_name)

	# Absolute (not *=), so applying stats twice can never compound the scale.
	sprite.scale = _base_sprite_scale * stats.sprite_scale


static func _has_any_frames(frames: SpriteFrames) -> bool:
	for anim_name in frames.get_animation_names():
		if frames.get_frame_count(anim_name) > 0:
			return true
	return false


func _physics_process(delta: float) -> void:
	if dead:
		return

	_tick_needs(delta)
	if dead:
		return  # starved

	_tick_ghost(delta)
	_tick_hurt(delta)
	_tick_attack(delta)

	# Knockback overrides the AI completely while it lasts.
	if _process_knockback(delta):
		return

	ai.update_ai(self, delta)

	# Blocked for a while (e.g. by a house)? Walk around it sideways for a moment.
	if _sidestep_left > 0.0:
		_sidestep_left -= delta
		desired_direction = desired_direction.rotated(_sidestep_sign * 1.1)

	var speed: float = desired_speed * speed_multiplier
	if hurt:
		speed *= hurt_speed_multiplier
	if hunger.is_empty():
		speed *= NeedsRules.HUNGRY_SPEED_FACTOR  # starving: half speed

	velocity = desired_direction * speed
	move_and_slide()
	_clamp_to_world()
	_update_stuck(delta)

	_update_visuals(delta)


# --------------------------------------------------
# COMBAT
# --------------------------------------------------

## Starts an attack. After `attack_windup` seconds the hit is checked with
## HitDetection: the target must still be inside the attack arc, which points
## where the target was when the attack started. Moving away = dodged.
func perform_attack(target_node: Node2D) -> void:
	if dead or _attack_windup_left > 0.0 or not is_instance_valid(target_node):
		return

	_attack_target = target_node
	_attack_direction = global_position.direction_to(target_node.global_position)
	_attack_windup_left = maxf(attack_windup, 0.0)
	attack_requested.emit(target_node)

	if projectile_scene != null:
		_begin_throw_animation()

	if _attack_windup_left <= 0.0:
		_resolve_attack()
	elif projectile_scene == null:
		sprite.modulate = WINDUP_TINT  # melee telegraph; throwers use the throw animation


func _tick_attack(delta: float) -> void:
	if _attack_windup_left <= 0.0:
		return
	_attack_windup_left -= delta
	if _attack_windup_left <= 0.0:
		_resolve_attack()


func _resolve_attack() -> void:
	sprite.modulate = Color.WHITE
	_attack_windup_left = 0.0

	var victim: Node2D = _attack_target
	_attack_target = null

	if not can_attack() or not is_instance_valid(victim) or not victim.has_method("take_hit"):
		return

	if projectile_scene != null:
		_release_projectile(victim)
		return

	var reach: float = attack_reach if attack_reach > 0.0 else attack_range + 6.0
	if HitDetection.is_in_arc(global_position, _attack_direction, victim.global_position, reach, attack_arc_degrees):
		# Starving halves the damage of melee attacks (thrown things are not melee).
		var melee_damage: float = attack_damage * (NeedsRules.HUNGRY_MELEE_FACTOR if hunger.is_empty() else 1.0)
		victim.take_hit(HitInfo.create(melee_damage, self, _attack_direction, attack_knockback))


# Being hit or knocked back interrupts a running attack.
func _cancel_attack() -> void:
	_throw_anim_playing = false
	if _attack_windup_left > 0.0:
		_attack_windup_left = 0.0
		_attack_target = null
		sprite.modulate = Color.WHITE


## True while this NPC may attack at all (alive and not knocked back like a ghost).
func can_attack() -> bool:
	return not dead and _ghost_time_left <= 0.0


## True while this NPC hurts the player on contact: it has to be an enemy of the player (hostile).
func can_hurt_player() -> bool:
	return can_attack() and is_hostile_to_player()


## Entry point for attacks that use HitInfo (player sword etc.).
func take_hit(hit: HitInfo) -> bool:
	if dead:
		return false

	_last_hit_class = hit.weapon_class
	_last_hit_direction = hit.direction

	var attacker: Node2D = hit.source if is_instance_valid(hit.source) else null
	if attacker != null and attacker != self:
		if attacker.is_in_group("player"):
			# Hitting a peaceful NPC is a hostile act: the player's standing with its faction drops (ActionWeight.HOSTILE).
			_hit_by_player = true
			_hostile_when_hit = is_hostile_to_player()
			if not _hostile_when_hit:
				Relations.apply_to_npc(self, ActionWeight.Type.HOSTILE)
		grudge_target = attacker
		_grudge_left = 12.0

	take_damage(hit.damage)

	# Sword knockback: no ghost phase, the enemy keeps colliding.
	if not dead and hit.knockback_distance > 0.0:
		apply_knockback(hit.direction, hit.knockback_distance, false)
	return true


func take_damage(amount: float) -> void:
	if amount <= 0.0 or dead:
		return

	# Armor: diminishing returns, never reaches 100 % reduction.
	amount *= 100.0 / (100.0 + maxf(armor, 0.0))

	health = maxf(health - amount, 0.0)

	if health <= 0.0:
		_die()
		return

	_cancel_attack()
	if dropper != null:
		dropper.drop_on_hurt()

	hurt = true
	_hurt_time_left = hurt_duration
	if _has_animation(hurt_anim):
		sprite.play(hurt_anim)


func _die() -> void:
	dead = true
	hurt = false
	_ghost_time_left = 0.0
	_knockback_distance_remaining = 0.0
	velocity = Vector2.ZERO

	# A dying enemy must not hurt, block or be hit anymore.
	_cancel_attack()

	# Killing an NPC that did not attack the player first is evil (ActionWeight.EVIL).
	if _hit_by_player and not _hostile_when_hit:
		Relations.apply_to_npc(self, ActionWeight.Type.EVIL)

	# Event NPCs drop by their rarity, normal NPCs drop what they carry.
	if is_event_npc:
		if dropper != null:
			dropper.drop_on_death()
	else:
		_drop_inventory()

	remove_from_group("npc")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if touch_hitbox != null:
		touch_hitbox.set_deferred("monitoring", false)

	died.emit(self)

	# How it dies depends on the class of the weapon that landed the killing hit:
	# heavy (rocket launcher) = it explodes into red goo, light (sword, AK-47) = it is shot down and leaves a
	# bloody corpse. Bigger for higher rarities (and for bigger sprites).
	var tier: int = int(rarity)
	DeathEffect.play_for(
		get_tree(), global_position + sprite.position, _last_hit_class, death_sheet_heavy, death_sheet_light,
		absf(sprite.scale.x) * (1.0 + 0.12 * float(tier)), 1.0 + 0.3 * float(tier), _last_hit_direction
	)
	queue_free()


func _tick_hurt(delta: float) -> void:
	if not hurt:
		return
	_hurt_time_left -= delta
	if _hurt_time_left <= 0.0:
		hurt = false


# --------------------------------------------------
# KNOCKBACK / GHOST
# --------------------------------------------------

## `ghost` = also switch collisions off and stop contact damage for
## knockback_immunity_duration (used by the jump attack, not by the sword).
func apply_knockback(direction: Vector2, distance: float = 160.0, ghost: bool = true) -> void:
	if direction.is_zero_approx() or dead:
		return

	_cancel_attack()
	_knockback_direction = direction.normalized()
	_knockback_distance_remaining = distance * (1.0 - knockback_resistance)
	if ghost:
		_start_ghost()


func _start_ghost() -> void:
	if _ghost_time_left <= 0.0:
		collision_layer = 0
		collision_mask = 0
	# Re-hitting restarts the timer.
	_ghost_time_left = knockback_immunity_duration


# A plain countdown instead of `await get_tree().create_timer()`:
# an awaiting function on a freed enemy produces "instance is gone" errors.
func _tick_ghost(delta: float) -> void:
	if _ghost_time_left <= 0.0:
		return
	_ghost_time_left -= delta
	if _ghost_time_left <= 0.0:
		collision_layer = _base_collision_layer
		collision_mask = _base_collision_mask


# Returns true while knockback is active.
func _process_knockback(delta: float) -> bool:
	if _knockback_distance_remaining <= 0.0:
		return false

	var step: float = minf(knockback_speed * delta, _knockback_distance_remaining)
	velocity = _knockback_direction * (step / delta)

	var previous_position: Vector2 = global_position
	move_and_slide()
	_clamp_to_world()
	var moved: float = previous_position.distance_to(global_position)

	_knockback_distance_remaining -= moved
	if moved < 0.01:
		_knockback_distance_remaining = 0.0

	return true


# Chasing but barely moving for half a second: pick a random side and sidestep.
func _update_stuck(delta: float) -> void:
	if ai.current_state != NpcAI.State.CHASE or desired_speed <= 0.0 or _sidestep_left > 0.0:
		_stuck_time = 0.0
		return

	var expected_speed: float = desired_speed * speed_multiplier
	if hurt:
		expected_speed *= hurt_speed_multiplier
	if hunger.is_empty():
		expected_speed *= NeedsRules.HUNGRY_SPEED_FACTOR

	if get_real_velocity().length() < expected_speed * 0.25:
		_stuck_time += delta
	else:
		_stuck_time = maxf(_stuck_time - delta * 2.0, 0.0)

	if _stuck_time >= 0.5:
		_stuck_time = 0.0
		var now: int = Time.get_ticks_msec()
		if now - _last_sidestep_msec < 3000:
			# Blocked again soon after sidestepping (a big building): keep the same direction, for longer.
			_sidestep_length = minf(_sidestep_length * 1.6, 3.0)
		else:
			_sidestep_length = 0.7
			_sidestep_sign = 1.0 if randf() < 0.5 else -1.0
		_sidestep_left = _sidestep_length
		_last_sidestep_msec = now


# While ghosted the collision mask is 0, so the world walls don't stop the
# enemy. Clamping keeps it inside the map in every case.
func _clamp_to_world() -> void:
	if not is_instance_valid(ai.manager):
		return
	var clamped: Vector2 = ai.manager.clamp_to_world(global_position)
	if clamped != global_position:
		global_position = clamped


# --------------------------------------------------
# VISUALS
# --------------------------------------------------

func _update_visuals(delta: float) -> void:
	# Throw animation running: let it play out, keep facing the target.
	if _throw_anim_playing:
		if sprite.is_playing() and sprite.animation == throw_anim:
			return
		_throw_anim_playing = false

	var facing: Vector2 = look_direction if not look_direction.is_zero_approx() else desired_direction

	# 8-direction sprites: turn step by step toward the new direction (looks like turning around).
	if direction_sheet != null:
		_facing.face_direction(facing)
		_facing.update(delta)
		sprite.flip_h = false
		if not hurt:
			var base: StringName = &"walk" if velocity.length() > 0.0 else &"idle"
			DirectionalFacing.play_keep_frame(sprite, _facing.anim_name(base))
		return

	if facing.x != 0.0:
		sprite.flip_h = facing.x < 0.0

	# Do not override the hurt animation.
	if hurt:
		return

	_play_animation(walk_anim if velocity.length() > 0.0 else idle_anim)


func _has_animation(anim_name: StringName) -> bool:
	return sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name)


func _play_animation(anim_name: StringName) -> void:
	# Skip missing animations instead of erroring.
	if not _has_animation(anim_name):
		return
	if sprite.animation != anim_name:
		sprite.play(anim_name)


func _on_animation_finished() -> void:
	if sprite.animation == throw_anim:
		_throw_anim_playing = false

	if dead and sprite.animation == death_anim:
		queue_free()
