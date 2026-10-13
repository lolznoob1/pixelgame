extends CharacterBody2D

signal died
signal item_collected(item: ItemData)
signal hit_taken(hit: HitInfo)

@export var speed: float = 70.0
@export var max_health: float = 100.0
## Health regained per second (live-adjustable in the developer menu).
@export var health_regen_rate: float = 2.0
@export var max_stamina: float = 100.0
@export var stamina_regen_rate: float = 10.0
## Health per second lost while enemies touch the player: threat 2 = this value, doubling per extra threat.
@export var contact_drain_base: float = 5.0
@export var ability1_cooldown: float = 5.0
@export var jump_height: float = 24.0
@export var jump_duration: float = 0.35
@export var jump_stamina_cost: float = 20.0

@export_group("Combat")
## How long the hurt state lasts (no control, knockback applies).
@export var hurt_duration: float = 0.25
## After a hit the player can't be hit again for this long.
@export var invulnerability_duration: float = 0.6
## The sword swing no longer locks the player: you can move, sprint, teleport, jump, throw a bottle and
## switch weapons while it plays. Walking speed during the swing (1 = full speed).
@export_range(0.0, 1.0) var attack_move_factor: float = 0.8
## true: the sword swing turns the player toward the mouse. false: toward the last movement direction.
@export var aim_with_mouse: bool = true

@export_group("Sprint")
## Hold Shift to run faster. Moving while sprinting drains stamina and pauses its regeneration.
@export var sprint_multiplier: float = 1.7
## Stamina per second while sprinting (0 = free sprint).
@export var sprint_stamina_cost: float = 6.0
## Sprinting is not possible below this stamina level.
@export var min_stamina_to_sprint: float = 10.0

@export_group("Secondary ability (right mouse button)")
## The icon in the bottom right shows the cooldown of this ability: the empty bottle fills with water.
## For another character use other textures: same size, plus the rows where the fill is.
@export var secondary_name: String = "Bottle"
@export var secondary_icon_empty: Texture2D = preload("res://assets/ui/bottle_empty.png")
@export var secondary_icon_full: Texture2D = preload("res://assets/ui/bottle_full.png")
@export var secondary_fill_top: int = 5
@export var secondary_fill_bottom: int = 20

@export_group("Death")
## Death animations (8 frames of 48 x 48 side by side), chosen by the class of the weapon that killed the player
## (enemy attacks are light: the player is shot down and leaves a corpse; a heavy hit would make it explode).
@export var death_sheet_heavy: Texture2D
@export var death_sheet_light: Texture2D
## Seconds between the explosion and the game over screen.
@export var death_delay: float = 1.0

@export_group("Teleport")
## The teleport (Q) damages enemies around the spot you arrive at.
@export var teleport_damage: float = 30.0
@export var teleport_radius: float = 20.0
@export var teleport_knockback: float = 20.0

@export_group("Teleport animation")
## The character is sucked into the center of its sprite, then the same animation plays backwards at the target.
@export var teleport_out_time: float = 0.18
@export var teleport_in_time: float = 0.18

@export_group("Bottle")
## Right mouse button: throws a glass bottle of water. Seconds between two throws.
@export var bottle_cooldown: float = 1.0
@export var bottle_damage: float = 20.0
## Maximum throwing distance in pixels (the bottle lands at the mouse, at most this far).
@export var bottle_range: float = 190.0
@export var bottle_knockback: float = 8.0

@export_group("Turning")
## 8-direction sprites; the player turns step by step toward the walking direction.
@export var direction_sheet: DirectionalSheet

@export_group("Drops")
## Rolled when the player is hit (default: loses some coins).
@export var hurt_drops: DropTable
## Rolled when stamina runs out (default: drops all coins).
@export var death_drops: DropTable

var health: float = 100.0
var stamina: float = 100.0
var health_bar: ProgressBar
var is_defeated: bool = false
var can_ability1: bool = true
var attacking: bool = false
var hurt: bool = false
var dead: bool = false
var is_jumping: bool = false
var jump_timer: float = 0.0
var player_visual: Node2D
var visual_start_position: Vector2

# Direction the player is facing (last movement direction). The sword arc points this way.
var facing_direction: Vector2 = Vector2.RIGHT

# Items: stackable pickups (coins) and timed power-ups.
var inventory: Inventory = Inventory.new()   # item id -> count (also holds the need items)
var speed_multiplier: float = 1.0
var damage_multiplier: float = 1.0
var dropper: ItemDropper

var _effects: Dictionary = {}    # item id -> {"item": ItemData, "time_left": float}
var _hurt_time_left: float = 0.0
var _invulnerable_left: float = 0.0
var _buff_label: Label
var _info_label: Label
var _health_text: Label
var _stamina_text: Label
var _hint_text: String = ""
var _hint_left: float = 0.0
var _gun_overlay: Sprite2D
var _gun_kick: float = 0.0

var sprinting: bool = false
## The weapon of the selected slot (null while the sword, slot 1, is selected).
var weapon: PlayerWeapon
## Weapons in slots 2 and 3 (slot -> PlayerWeapon). At most one of each type.
var _owned_weapons: Dictionary = {}
var current_slot: int = 1
var _hotbar_slots: Dictionary = {}  # slot -> {"panel", "icon", "ammo", "style"}
var _dust_timer: float = 0.0

var _facing_turn: DirectionalFacing = DirectionalFacing.new()
var _bottle_cooldown_left: float = 0.0
var _ability1_left: float = 0.0
var _flash_left: float = 0.0

# Upgrades bought with coins (see UpgradeCatalog)
var upgrade_levels: Dictionary = {}
var damage_bonus: float = 0.0
var damage_reduction: float = 0.0
var _base_speed: float = 0.0
var _health_regen_bonus: float = 0.0
var _death_timer: float = 0.0
var _last_hit_class: WeaponClass.Type = WeaponClass.Type.LIGHT
var _last_hit_direction: Vector2 = Vector2.ZERO
var _secondary_gauge: AbilityGauge
var _coin_counter: CoinCounter
var _hunger_gauge: StageGauge
var _thirst_gauge: AbilityGauge

## Needs: both start at 100 and run down (hunger by NpcType PLAYER, thirst by NeedsRules). Hunger at 0 hurts.
var hunger: Need = Need.new()
var thirst: Need = Need.new()
## Abilities the player has to unlock (health regeneration, stamina regeneration while sprinting / jumping).
var abilities: PlayerAbilities = PlayerAbilities.new()
## The object the player stands at and can use with E (a store entrance, a faction storage).
var interact_target: Node
var interact_cooldown: float = 0.0
## How many ability cores were collected (each shortens the bottle and teleport cooldowns).
var ability_cores: int = 0
const MIN_BOTTLE_COOLDOWN: float = 0.25
const MIN_TELEPORT_COOLDOWN: float = 0.5

enum TeleportPhase { NONE, OUT, IN }
# The same green as the Stamina Drink item sprite.
const STAMINA_COLOR: Color = Color(0.298, 0.914, 0.380)
var _tp_phase: TeleportPhase = TeleportPhase.NONE
var _tp_time: float = 0.0
var _tp_target: Vector2 = Vector2.ZERO
var _base_sprite_scale: Vector2 = Vector2.ONE
var _stamina_regen_bonus: float = 0.0

# Alle Gegner, die den Spieler momentan berühren
var touching_enemies: Dictionary = {}

@onready var stamina_bar: ProgressBar = $CanvasLayer/StaminaBar
# Added in main.tscn, so look it up safely (player.tscn alone has none).
@onready var jump_attack_area: Area2D = get_node_or_null("JumpAttackArea")
@onready var attack_node: Node = get_node_or_null("attack")
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Enemies find the player through this group (don't rely on main.tscn setting it).
	add_to_group("player")
	health = max_health
	stamina = max_stamina
	_create_hud()

	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("idle")
	# Replace Sprite2D with the actual name of your visual node
	player_visual = $AnimatedSprite2D
	visual_start_position = player_visual.position

	_ensure_input_actions()
	_ensure_bottle_action()
	_ensure_weapon_actions()
	_ensure_need_actions()
	_setup_needs()
	_setup_dropper()

	_base_speed = speed
	_base_sprite_scale = sprite.scale
	if not DevSettings.player_initialized:
		DevSettings.init_from_player(self)
	DirectionalFacing.build_animations(sprite.sprite_frames, direction_sheet)
	_facing_turn.snap_to(Vector2.DOWN)
	_recalculate_modifiers()


func _physics_process(delta: float) -> void:
	_enforce_out_of_bounds()

	# Teleport animation running: no control until it is finished.
	if _tp_phase != TeleportPhase.NONE:
		_tick_teleport(delta)
		return

	# Dead: the explosion plays, then the game over screen comes after death_delay.
	if dead:
		velocity = Vector2.ZERO
		if _death_timer > 0.0:
			_death_timer -= delta
			if _death_timer <= 0.0:
				died.emit()
		return
	if hurt:
		# velocity = the knockback impulse set in take_hit()
		move_and_slide()
		_hurt_time_left -= delta
		if _hurt_time_left <= 0.0:
			hurt = false
			velocity = Vector2.ZERO
		return

	# Teleport mit Q / ability1
	if Input.is_action_just_pressed("ability1") and can_ability1:
		var teleport_target: Vector2 = _clamp_to_world(get_global_mouse_position())
		if _is_inside_house(teleport_target):
			# Refused: no teleport and the cooldown is not used up.
			_show_hint("Can't teleport into a house")
		else:
			_start_teleport(teleport_target)
			return

	# Jump Attack
	if Input.is_action_just_pressed("jump_attack"):
		start_jump_attack()
		return

	# WASD-Bewegung
	var direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	# Sprint (Shift): needs stamina, not possible while shooting.
	var shooting_input: bool = weapon != null and Input.is_action_pressed("attack") and weapon.ammo > 0
	sprinting = (
		Input.is_action_pressed("sprint")
		and direction != Vector2.ZERO
		and stamina >= min_stamina_to_sprint
		and not shooting_input
	)

	var move_speed: float = speed * speed_multiplier * need_speed_factor() * (sprint_multiplier if sprinting else 1.0)
	if attacking:
		move_speed *= attack_move_factor  # the swing keeps playing while you move
	velocity = direction * move_speed

	if direction != Vector2.ZERO:
		facing_direction = direction.normalized()

	# Sprite nach links oder rechts drehen (not during the swing: it keeps the direction it was started in)
	if direction.x != 0 and not attacking:
		sprite.flip_h = direction.x < 0

	move_and_slide()

	if sprinting:
		_dust_timer -= delta
		if _dust_timer <= 0.0:
			_dust_timer = 0.08
			Fx.sprint_dust(get_tree(), global_position + Vector2(0.0, 5.0), direction)

	if Input.is_action_just_pressed("throw_bottle"):
		_throw_bottle()

	# Needs: G eats a food item from the inventory, B drinks a drink.
	if Input.is_action_just_pressed("eat"):
		_consume(ItemData.Effect.FOOD)
	if Input.is_action_just_pressed("drink"):
		_consume(ItemData.Effect.DRINK)

	# E uses the object the player stands at (store entrance, faction storage).
	interact_cooldown = maxf(interact_cooldown - delta, 0.0)
	if is_instance_valid(interact_target):
		_show_hint(String(interact_target.call("prompt")))
		if Input.is_action_just_pressed("interact") and interact_cooldown <= 0.0:
			interact_target.call("interact", self)

	# Weapon slots: 1 = sword, 2 = AK-47, 3 = rocket launcher.
	if Input.is_action_just_pressed("weapon_1"):
		_select_slot(1)
	elif Input.is_action_just_pressed("weapon_2"):
		_select_slot(2)
	elif Input.is_action_just_pressed("weapon_3"):
		_select_slot(3)

	# With a weapon selected the attack button fires it instead of swinging the sword.
	if weapon != null:
		_update_weapon(direction, delta)
		return

	# Auto attack (Options): swing at the nearest enemy that is inside the sword's reach.
	if GameSettings.auto_attack and attack_node != null and attack_node.can_attack():
		var auto_target: Node2D = _find_sword_target()
		if auto_target != null:
			attack(global_position.direction_to(auto_target.global_position))
			return

	# Schwertangriff
	if Input.is_action_just_pressed("attack"):
		attack()
		return

	# Turn toward the movement direction (step by step), then play the matching 8-direction animation.
	_facing_turn.face_direction(direction)
	_facing_turn.update(delta)

	# The swing animation plays out while you move; it is not replaced by walk / idle.
	# (Safety: if something else changed the animation, the swing is over.)
	if attacking:
		if sprite.animation == &"attack_sword":
			return
		attacking = false

	if direction.length() > 0:
		_play_directional(&"sprint" if sprinting else &"walk")
	else:
		_play_directional(&"idle")


# 8-direction animation (walk_e, idle_nw, ...). Falls back to the plain animation without a direction sheet.
func _play_directional(base: StringName) -> void:
	if direction_sheet == null:
		play_animation(String(base))
		return
	sprite.flip_h = false
	DirectionalFacing.play_keep_frame(sprite, _facing_turn.anim_name(base))


func play_animation(anim_name: String, playback_speed: float = 1.0) -> void:
	sprite.speed_scale = playback_speed
	if sprite.animation != anim_name:
		sprite.play(anim_name)


## `aim_override`: swing toward this direction (auto attack). Without it the sword turns toward the mouse.
func attack(aim_override: Vector2 = Vector2.ZERO) -> void:
	if dead or hurt or attacking:
		return

	# Turn toward the target (auto attack) or the mouse for the swing.
	if not aim_override.is_zero_approx():
		facing_direction = aim_override.normalized()
		_facing_turn.face_direction(facing_direction)
	elif aim_with_mouse:
		var aim: Vector2 = _mouse_direction()
		facing_direction = aim
		_facing_turn.face_direction(aim)

	# The attack node owns damage + cooldown. On cooldown: no swing, no animation lock.
	if attack_node != null and attack_node.has_method("try_attack"):
		if not attack_node.try_attack(facing_direction, damage_multiplier):
			return

	attacking = true
	sprite.speed_scale = 1.0
	sprite.flip_h = facing_direction.x < 0.0  # the sword frames are a side view
	sprite.play("attack_sword")


func _on_animation_finished() -> void:
	match sprite.animation:
		"attack_sword":
			attacking = false
			# Return to idle when the attack finishes
			sprite.play("idle")

		"hurt":
			hurt = false
			sprite.play("idle")

		"death":
			queue_free()

	if health <= 0.0:
		die()


func die() -> void:
	dead = true
	attacking = false
	hurt = false
	velocity = Vector2.ZERO


func update_jump(delta: float) -> void:
	if not is_jumping:
		return

	jump_timer += delta

	var progress: float = minf(jump_timer / jump_duration, 1.0)

	# Move the sprite upward and then back down
	var jump_offset: float = -sin(progress * PI) * jump_height
	player_visual.position = visual_start_position + Vector2(0, jump_offset)

	queue_redraw()  # the ground shadow follows the jump

	if progress >= 1.0:
		is_jumping = false
		jump_timer = 0.0
		player_visual.position = visual_start_position
		Fx.jump_land(get_tree(), _jump_ground_position(), _jump_zone_radius())


func start_teleport_cooldown() -> void:
	_ability1_left = ability1_cooldown  # ticked down in _update_tint_and_hud


func perform_jump_attack() -> void:
	if jump_attack_area == null:
		return

	for enemy in jump_attack_area.get_overlapping_bodies():
		if not enemy.is_in_group("npc"):
			continue

		if not enemy.has_method("apply_knockback"):
			continue

		# Always push away from the player. (The old "opposite of the enemy's
		# velocity" pushed circling enemies sideways, and stationary ones randomly.)
		var knockback_direction: Vector2 = enemy.global_position - global_position
		if knockback_direction.is_zero_approx():
			knockback_direction = Vector2.from_angle(randf() * TAU)

		enemy.apply_knockback(knockback_direction.normalized(), 160.0)


func _process(delta: float) -> void:
	update_jump(delta)
	_tick_effects(delta)
	_update_tint_and_hud(delta)
	if is_defeated:
		return

	# Bedrohung = Summe der contact_damage-Werte aller berührenden Gegner.
	# Gegner ohne contact_damage zählen als 1.0. Gelöschte Gegner werden entfernt;
	# tote oder zurückgeschleuderte ("Ghost") Gegner zählen nicht mit.
	var threat: float = 0.0
	for id in touching_enemies.keys():
		var entry: Variant = touching_enemies[id]

		if not is_instance_valid(entry):
			touching_enemies.erase(id)
			continue

		var touching_enemy := entry as Node2D
		if touching_enemy.has_method("can_hurt_player") and not touching_enemy.can_hurt_player():
			continue

		var dmg: Variant = touching_enemy.get("contact_damage")
		threat += float(dmg) if dmg != null else 1.0

	# Shield: contact drains nothing.
	if _has_effect(ItemData.Effect.SHIELD) or _tp_phase != TeleportPhase.NONE:
		threat = 0.0

	# Contact with enemies hurts HEALTH: threat 2 = 5/s, 3 = 10/s, 4 = 20/s usw.
	if threat >= 2.0:
		health -= contact_drain_base * pow(2.0, threat - 2.0) * delta

	_update_needs(delta)

	# Health regeneration is an ability that has to be unlocked (developer menu: Player > Health regeneration,
	# plus the upgrades bought in the shop).
	if abilities.has(PlayerAbilities.HEALTH_REGEN):
		health += (DevSettings.health_regen + _health_regen_bonus) * delta

	# Stamina: sprinting and the jump attack use it. It regenerates while walking or standing still, but NOT while
	# sprinting or jumping, unless the ability for that is unlocked.
	if sprinting:
		stamina -= sprint_stamina_cost * delta
	var regenerates: bool = not (sprinting or is_jumping) or abilities.has(PlayerAbilities.STAMINA_REGEN_ACTIVE)
	if regenerates:
		stamina += (DevSettings.stamina_regen + _stamina_regen_bonus) * delta

	stamina = clampf(stamina, 0.0, max_stamina)
	health = clampf(health, 0.0, max_health)

	if health <= 0.0:
		_trigger_defeat()


func start_jump_attack() -> void:
	if is_jumping or is_defeated:
		return

	if stamina < jump_stamina_cost:
		return

	stamina -= jump_stamina_cost
	_cancel_sword_swing()

	is_jumping = true
	jump_timer = 0.0

	perform_jump_attack()

	# Superhero take-off: air decompression + cracks, sized like the knockback zone.
	Fx.jump_burst(get_tree(), _jump_ground_position(), _jump_zone_radius())


func register_touching_enemy(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return

	if not enemy.is_in_group("npc"):
		return

	touching_enemies[enemy.get_instance_id()] = enemy


func unregister_touching_enemy(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return

	touching_enemies.erase(enemy.get_instance_id())


# Keeps a position inside the world (the teleport used to leave the map).
func _clamp_to_world(pos: Vector2) -> Vector2:
	var bounds := get_tree().get_first_node_in_group("world_bounds")
	if bounds != null and bounds.has_method("clamp_to_world"):
		return bounds.clamp_to_world(pos, 8.0)
	return pos


# --------------------------------------------------
# COMBAT: being hit
# --------------------------------------------------

## Direction of the sword arc: movement direction, or the mouse if aim_with_mouse.
func get_attack_direction() -> Vector2:
	if aim_with_mouse:
		var to_mouse: Vector2 = get_global_mouse_position() - global_position
		if not to_mouse.is_zero_approx():
			return to_mouse.normalized()
	return facing_direction


## Entry point for enemy attacks (see HitInfo). Returns true if the hit landed.
func take_hit(hit: HitInfo) -> bool:
	if dead or is_defeated or _tp_phase != TeleportPhase.NONE:
		return false  # (untouchable while teleporting)
	if _invulnerable_left > 0.0 or _has_effect(ItemData.Effect.SHIELD):
		return false

	_last_hit_class = hit.weapon_class
	_last_hit_direction = hit.direction

	# Armor upgrade lowers all hit damage.
	health = maxf(health - hit.damage * (1.0 - damage_reduction), 0.0)

	_invulnerable_left = invulnerability_duration

	if hit.stun:
		# Stunned: no control for hurt_duration, knockback is applied as a push.
		hurt = true
		attacking = false
		_hurt_time_left = hurt_duration
		velocity = hit.direction * (hit.knockback_distance / maxf(hurt_duration, 0.01))
	else:
		# Damage only (e.g. the thrown shoe): the player keeps control, just a short red flash.
		_flash_left = 0.15
		if hit.knockback_distance > 0.0:
			move_and_collide(hit.direction * hit.knockback_distance)

	hit_taken.emit(hit)

	if health <= 0.0:
		_trigger_defeat()
	elif dropper != null:
		dropper.drop_on_hurt()

	return true


# Single place for "the player has run out of health".
func _trigger_defeat() -> void:
	if is_defeated:
		return
	is_defeated = true
	dead = true
	attacking = false
	hurt = false
	if dropper != null:
		dropper.drop_on_death()
	_begin_death_animation()


# The player explodes into red goo; `died` is emitted after death_delay (see _physics_process).
func _begin_death_animation() -> void:
	_tp_phase = TeleportPhase.NONE
	sprite.scale = _base_sprite_scale
	sprite.rotation = 0.0
	sprite.visible = false
	if _gun_overlay != null:
		_gun_overlay.visible = false
	_death_timer = death_delay
	DeathEffect.play_for(
		get_tree(), global_position + sprite.position, _last_hit_class, death_sheet_heavy, death_sheet_light,
		1.4, 1.6, _last_hit_direction
	)


func _setup_dropper() -> void:
	dropper = get_node_or_null("ItemDropper") as ItemDropper
	if dropper == null:
		dropper = ItemDropper.new()
		dropper.name = "ItemDropper"
		add_child(dropper)
	if dropper.hurt_drops == null:
		dropper.hurt_drops = hurt_drops
	if dropper.death_drops == null:
		dropper.death_drops = death_drops


# --------------------------------------------------
# ITEMS
# --------------------------------------------------

## Used by pickups so full-health / full-stamina players don't waste them.
func can_collect_item(item: ItemData) -> bool:
	if item.effect == ItemData.Effect.STAMINA:
		return stamina < max_stamina
	if item.effect == ItemData.Effect.HEALTH:
		return health < max_health
	if item.effect == ItemData.Effect.AK47 or item.effect == ItemData.Effect.ROCKET:
		# One weapon per type: another pickup only adds ammo, unless that weapon is full.
		var owned: PlayerWeapon = _owned_weapons.get(_weapon_slot_for(item.effect))
		return owned == null or not owned.is_full()
	return true


## Called by ItemPickup. Returns true if the item was consumed.
func collect_item(item: ItemData) -> bool:
	if item == null or is_defeated or not can_collect_item(item):
		return false

	match item.effect:
		ItemData.Effect.COIN:
			inventory.add(item.id, maxi(1, int(item.amount)))
		ItemData.Effect.FOOD, ItemData.Effect.DRINK:
			inventory.add(item.id, 1)  # kept for later: eat with G, drink with B
		ItemData.Effect.STAMINA:
			stamina = minf(stamina + item.amount, max_stamina)
		ItemData.Effect.HEALTH:
			health = minf(health + item.amount, max_health)
		ItemData.Effect.AK47, ItemData.Effect.ROCKET:
			if not _pickup_weapon(item):
				return false
		ItemData.Effect.ABILITY:
			_apply_ability_core(item.amount)
		_:
			# Timed power-up. Picking it up again refreshes the timer (no stacking).
			_effects[item.id] = {"item": item, "time_left": item.duration}
			_recalculate_modifiers()

	item_collected.emit(item)
	return true


# Ability core: the cooldowns of the bottle and the teleport get shorter for good, and are reset right now.
func _apply_ability_core(fraction: float) -> void:
	var factor: float = 1.0 - clampf(fraction, 0.0, 0.9)
	bottle_cooldown = maxf(bottle_cooldown * factor, MIN_BOTTLE_COOLDOWN)
	ability1_cooldown = maxf(ability1_cooldown * factor, MIN_TELEPORT_COOLDOWN)
	_bottle_cooldown_left = 0.0
	_ability1_left = 0.0
	can_ability1 = true
	ability_cores += 1
	_show_hint("Ability core: cooldowns -%d%%" % roundi(fraction * 100.0))


func get_item_count(item_id: StringName) -> int:
	return inventory.count(item_id)


## Removes up to `count` of an item and returns how many were really removed.
## Used by DropEntry.from_inventory (the player loses coins when hit).
func take_from_inventory(item_id: StringName, count: int) -> int:
	return inventory.remove(item_id, count)


func _has_effect(effect: ItemData.Effect) -> bool:
	for entry: Dictionary in _effects.values():
		if (entry["item"] as ItemData).effect == effect:
			return true
	return false


func _tick_effects(delta: float) -> void:
	if _effects.is_empty():
		return

	var changed: bool = false
	for id in _effects.keys():
		var entry: Dictionary = _effects[id]
		entry["time_left"] = float(entry["time_left"]) - delta
		if float(entry["time_left"]) <= 0.0:
			_effects.erase(id)
			changed = true

	if changed:
		_recalculate_modifiers()


func _recalculate_modifiers() -> void:
	speed_multiplier = 1.0
	damage_multiplier = 1.0 + damage_bonus
	for entry: Dictionary in _effects.values():
		var item := entry["item"] as ItemData
		match item.effect:
			ItemData.Effect.SPEED:
				speed_multiplier += item.amount
			ItemData.Effect.DAMAGE:
				damage_multiplier += item.amount


# --------------------------------------------------
# FEEDBACK (placeholder HUD + tint)
# --------------------------------------------------

func _create_hud() -> void:
	var canvas := get_node_or_null("CanvasLayer")
	if canvas == null:
		return

	# ---- bottom left: active buffs, with the health and stamina bars below them ----
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	canvas.add_child(left)

	_buff_label = _make_hud_label(HORIZONTAL_ALIGNMENT_LEFT)
	left.add_child(_buff_label)

	health_bar = ProgressBar.new()
	left.add_child(health_bar)
	_style_bar(health_bar, Color(0.85, 0.2, 0.2), Vector2(240.0, 20.0))
	_health_text = _add_bar_text(health_bar)

	stamina_bar.reparent(left, false)
	_style_bar(stamina_bar, STAMINA_COLOR, Vector2(240.0, 16.0))
	_stamina_text = _add_bar_text(stamina_bar)

	left.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	left.grow_vertical = Control.GROW_DIRECTION_BEGIN  # grows upward when buffs appear

	# ---- bottom right: coins and hints, with the secondary ability gauge below ----
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	canvas.add_child(right)

	_info_label = _make_hud_label(HORIZONTAL_ALIGNMENT_RIGHT)
	_info_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(_info_label)

	# The coin counter sits next to the bottle gauge (both are 66 px tall).
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(row)

	# Hunger: the sandwich gets eaten bite by bite. Thirst: the beer mug empties (and fills up again when you drink).
	_hunger_gauge = StageGauge.new()
	_hunger_gauge.strip = preload("res://assets/ui/sandwich_stages.png")
	row.add_child(_hunger_gauge)

	_thirst_gauge = AbilityGauge.new()
	_thirst_gauge.set_icons(preload("res://assets/ui/beer_empty.png"), preload("res://assets/ui/beer_full.png"), 4, 20)
	_thirst_gauge.foam_color = Color(1.0, 0.99, 0.94)
	_thirst_gauge.foam_rows = 2
	_thirst_gauge.foam_x0 = 3
	_thirst_gauge.foam_x1 = 10
	row.add_child(_thirst_gauge)

	_coin_counter = CoinCounter.new()
	row.add_child(_coin_counter)

	_secondary_gauge = AbilityGauge.new()
	_secondary_gauge.set_icons(secondary_icon_empty, secondary_icon_full, secondary_fill_top, secondary_fill_bottom)
	row.add_child(_secondary_gauge)

	right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.grow_vertical = Control.GROW_DIRECTION_BEGIN

	_create_hotbar(canvas)
	_update_bars()


func _make_hud_label(alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = alignment
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return label


func _style_bar(bar: ProgressBar, color: Color, min_size: Vector2) -> void:
	bar.show_percentage = false
	bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END
	bar.step = 0.0
	bar.min_value = 0.0
	bar.custom_minimum_size = min_size

	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.1, 0.1, 0.12, 0.8)
	background.border_color = Color(0.0, 0.0, 0.0, 0.9)
	background.set_border_width_all(1)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", background)


# The number ("87 / 100") drawn inside a bar.
func _add_bar_text(bar: ProgressBar) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	bar.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return label


func _update_bars() -> void:
	if health_bar != null:
		health_bar.max_value = max_health
		health_bar.value = health
	if _health_text != null:
		_health_text.text = "%d / %d" % [roundi(health), roundi(max_health)]

	stamina_bar.max_value = max_stamina
	stamina_bar.value = stamina
	if _stamina_text != null:
		_stamina_text.text = "%d / %d" % [roundi(stamina), roundi(max_stamina)]


func _update_tint_and_hud(delta: float) -> void:
	_update_bars()
	_update_hotbar()
	_hint_left = maxf(_hint_left - delta, 0.0)
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	_flash_left = maxf(_flash_left - delta, 0.0)
	_bottle_cooldown_left = maxf(_bottle_cooldown_left - delta, 0.0)
	if _ability1_left > 0.0:
		_ability1_left -= delta
		if _ability1_left <= 0.0:
			can_ability1 = true

	# Tint: red while hurt, blue with shield, light green/red with speed/damage boost.
	if _tp_phase != TeleportPhase.NONE:
		sprite.modulate = Color(1.2, 1.5, 1.7)  # glows while dematerialized
	elif hurt or _flash_left > 0.0:
		sprite.modulate = Color(1.0, 0.45, 0.45)
	elif _has_effect(ItemData.Effect.SHIELD):
		sprite.modulate = Color(0.65, 0.85, 1.0)
	elif speed_multiplier > 1.0:
		sprite.modulate = Color(0.8, 1.0, 0.8)
	elif damage_multiplier > 1.0:
		sprite.modulate = Color(1.0, 0.85, 0.85)
	else:
		sprite.modulate = Color.WHITE

	if _buff_label == null:
		return

	# Active buffs (speed boost, shield, ...): above the health and stamina bars.
	var buffs: PackedStringArray = []
	for entry: Dictionary in _effects.values():
		var item := entry["item"] as ItemData
		buffs.append("%s  %.1fs" % [item.display_name, float(entry["time_left"])])
	# Mood (from the thirst) and the hungry debuff.
	var mood: Happiness.State = get_happiness()
	if mood != Happiness.State.UNREST:
		buffs.append("%s  (%+d%% speed)" % [Happiness.display_name(mood), roundi((Happiness.speed_modifier(mood) - 1.0) * 100.0)])
	if hunger.is_empty():
		buffs.append("STARVING  -50% speed, -50% melee damage, losing health")
	_buff_label.text = "\n".join(buffs)
	_buff_label.visible = not buffs.is_empty()

	# Bottom right: coins, bottle cooldown, rifle ammo, hints.
	var info: PackedStringArray = []
	if _coin_counter != null:
		_coin_counter.set_count(get_item_count(&"coin"))  # spins when it goes up
	info.append("[T]  Upgrades & Shop")
	if _secondary_gauge != null:
		_secondary_gauge.set_fill(1.0 - _bottle_cooldown_left / maxf(bottle_cooldown, 0.01))
	if _hunger_gauge != null:
		_hunger_gauge.set_fraction(hunger.fraction())
		_hunger_gauge.set_alert(hunger.is_empty())
	if _thirst_gauge != null:
		_thirst_gauge.set_fill(thirst.fraction())
	if _hint_left > 0.0:
		info.append(_hint_text)
	_info_label.text = "\n".join(info)


# --------------------------------------------------
# WEAPON SLOTS
# --------------------------------------------------
# 1 = sword (always), 2 = AK-47, 3 = rocket launcher. Keys 1 / 2 / 3 select a slot. Only one weapon of each
# type can be carried: another pickup adds ammo. A weapon is thrown away when its ammo is used up.

const SLOT_SWORD: int = 1
const SWORD_ICON: Texture2D = preload("res://assets/weapons/sword.png")
const SLOT_ICONS: Dictionary = {
	1: SWORD_ICON,
	2: Ak47Weapon.ICON,
	3: RocketLauncherWeapon.ICON,
}


func _weapon_slot_for(effect: ItemData.Effect) -> int:
	match effect:
		ItemData.Effect.AK47:
			return 2
		ItemData.Effect.ROCKET:
			return 3
	return 0


func _create_weapon(effect: ItemData.Effect) -> PlayerWeapon:
	match effect:
		ItemData.Effect.AK47:
			return Ak47Weapon.new()
		ItemData.Effect.ROCKET:
			return RocketLauncherWeapon.new()
	return null


## First pickup of a weapon type: it goes into its slot and is selected. Every further pickup
## (or shop purchase) adds ammo, up to the weapon's maximum.
func _pickup_weapon(item: ItemData) -> bool:
	var slot: int = _weapon_slot_for(item.effect)
	var owned: PlayerWeapon = _owned_weapons.get(slot)
	if owned != null:
		return owned.add_ammo(int(item.amount))

	var new_weapon: PlayerWeapon = _create_weapon(item.effect)
	if new_weapon == null:
		return false

	new_weapon.name = new_weapon.display_name
	add_child(new_weapon)
	new_weapon.setup(self, int(item.amount))
	new_weapon.register_animations(sprite.sprite_frames)
	new_weapon.emptied.connect(_toss_weapon.bind(slot))
	new_weapon.fired.connect(_on_weapon_fired)
	_owned_weapons[slot] = new_weapon

	_select_slot(slot)  # (also ends a running sword swing)
	return true


func _select_slot(slot: int) -> void:
	if slot == current_slot:
		return
	if slot != SLOT_SWORD and not _owned_weapons.has(slot):
		_show_hint("No weapon in slot %d" % slot)
		return

	_cancel_sword_swing()
	current_slot = slot
	weapon = _owned_weapons.get(slot) as PlayerWeapon  # null for the sword

	_gun_kick = 0.0
	if _gun_overlay != null:
		_gun_overlay.visible = false
	sprite.speed_scale = 1.0
	_facing_turn.snap_to(facing_direction)


func _update_weapon(direction: Vector2, delta: float) -> void:
	# The weapon aims at the mouse and the whole character turns toward it (8 directions).
	var aim: Vector2 = _mouse_direction()
	facing_direction = aim
	_facing_turn.face_direction(aim)
	_facing_turn.update(delta)

	# Mostly up or down: the weapon animation frames are a side view, so the turned body
	# (back / front view) is drawn instead, with the weapon's icon pointing at the mouse.
	var vertical: bool = absf(aim.x) < 0.5 * absf(aim.y)
	var hand: Vector2 = Vector2(4.0, 3.0) if aim.y > 0.0 else Vector2(-4.0, -1.0)
	var muzzle: Vector2 = _get_muzzle_position(aim, vertical, hand)

	# Automatic weapons fire while the button is held, the others once per click.
	var wants_fire: bool = Input.is_action_pressed("attack") if weapon.automatic else Input.is_action_just_pressed("attack")
	if wants_fire and weapon.ammo > 0:
		weapon.try_fire(aim, muzzle, damage_multiplier)

	if vertical:
		sprite.flip_h = false
		_play_directional(&"sprint" if sprinting else (&"walk" if direction != Vector2.ZERO else &"idle"))
		_update_gun_overlay(true, aim, hand, delta)
		return

	_update_gun_overlay(false, aim, hand, delta)
	sprite.flip_h = aim.x < 0.0

	if weapon.fire_anim_left > 0.0:
		play_animation(String(weapon.anim_fire), weapon.fire_anim_speed)
	elif direction != Vector2.ZERO and sprite.sprite_frames.has_animation(weapon.anim_walk):
		play_animation(String(weapon.anim_walk), 1.6 if sprinting else 1.0)  # a real walk cycle, not the idle frames
	else:
		play_animation(String(weapon.anim_idle), 1.0)


# The weapon's icon pointing at the mouse, for the front / back views (aiming down / up).
# Drawn behind the body when aiming up.
func _update_gun_overlay(visible_now: bool, aim: Vector2, hand: Vector2, delta: float) -> void:
	if _gun_overlay == null:
		_gun_overlay = Sprite2D.new()
		add_child(_gun_overlay)

	_gun_overlay.visible = visible_now and weapon != null
	if not _gun_overlay.visible:
		return

	_gun_overlay.texture = weapon.icon
	_gun_kick = maxf(_gun_kick - delta * 8.0, 0.0)
	_gun_overlay.z_index = 1 if aim.y > 0.0 else -1
	_gun_overlay.position = sprite.position + hand + aim * (3.0 - 2.0 * _gun_kick)
	_gun_overlay.rotation = aim.angle()
	_gun_overlay.flip_v = aim.x < 0.0


# Direction from the player to the mouse (falls back to the facing direction).
func _mouse_direction() -> Vector2:
	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	if to_mouse.is_zero_approx():
		return facing_direction
	return to_mouse.normalized()


# Where a shot leaves the weapon. Side view: measured on the weapon's animation frames.
func _get_muzzle_position(aim: Vector2, vertical: bool = false, hand: Vector2 = Vector2.ZERO) -> Vector2:
	if vertical:
		return global_position + sprite.position + hand + aim * weapon.muzzle_vertical
	var side: float = -1.0 if aim.x < 0.0 else 1.0
	return global_position + sprite.position + Vector2(weapon.muzzle_side.x * side, weapon.muzzle_side.y)


func _on_weapon_fired() -> void:
	_gun_kick = 1.0  # recoil of the weapon sprite (front / back views)


# --------------------------------------------------
# NEEDS (hunger, thirst), MOOD, INTERACTION
# --------------------------------------------------

func _setup_needs() -> void:
	hunger.rate_per_minute = NpcType.hunger_per_minute(NpcType.Type.PLAYER)
	thirst.rate_per_minute = NeedsRules.PLAYER_THIRST_PER_MINUTE


# Both needs run down. A player with no hunger left loses health.
func _update_needs(delta: float) -> void:
	hunger.tick(delta)
	thirst.tick(delta)
	if hunger.is_empty():
		health -= NeedsRules.STARVE_DAMAGE_PER_SECOND * delta


## The mood of the player: the thirst decides it (80-100 happy, 50-79 unrest, 10-49 unhappy, 0-9 depressed).
func get_happiness() -> Happiness.State:
	return Happiness.from_drink(thirst.value)


## Walking speed factor from the mood (happy +20 %, unhappy -10 %, depressed -40 %) and from starving (-50 %).
func need_speed_factor() -> float:
	var factor: float = Happiness.speed_modifier(get_happiness())
	if hunger.is_empty():
		factor *= NeedsRules.HUNGRY_SPEED_FACTOR
	return factor


## Melee damage factor: starving halves the damage of the sword.
func melee_factor() -> float:
	return NeedsRules.HUNGRY_MELEE_FACTOR if hunger.is_empty() else 1.0


# Eats / drinks one item of that kind from the inventory.
func _consume(effect: ItemData.Effect) -> void:
	if is_defeated or dead:
		return

	var eating: bool = effect == ItemData.Effect.FOOD
	var need: Need = hunger if eating else thirst
	for item_id in inventory.ids():
		var item: ItemData = ItemDatabase.get_item(item_id)
		if item == null or item.effect != effect:
			continue
		if need.is_full():
			_show_hint("Not hungry" if eating else "Not thirsty")
			return
		inventory.remove(item_id, 1)
		var amount: float = ItemEconomy.restore_of(item)
		need.restore(amount)
		_show_hint("%s  +%d %s" % [item.display_name, roundi(amount), "hunger" if eating else "thirst"])
		return

	_show_hint("No food (G)" if eating else "No drink (B)")


func set_interact_target(target: Node) -> void:
	interact_target = target


func clear_interact_target(target: Node) -> void:
	if interact_target == target:
		interact_target = null


# Ends the sword swing early (an ability with its own animation starts).
func _cancel_sword_swing() -> void:
	if attacking:
		attacking = false
		sprite.speed_scale = 1.0


## Out of ammo: the weapon is thrown away and the slot is empty again.
func _toss_weapon(slot: int) -> void:
	var tossed: PlayerWeapon = _owned_weapons.get(slot)
	if tossed == null:
		return

	TossedWeapon.launch(
		get_tree(), global_position + sprite.position + Vector2(0.0, -2.0),
		facing_direction, tossed.icon
	)
	_owned_weapons.erase(slot)
	tossed.queue_free()

	# If it was the selected one, fall back to the sword.
	if current_slot == slot:
		current_slot = -1
		_select_slot(SLOT_SWORD)


# --------------------------------------------------
# HOTBAR (bottom center)
# --------------------------------------------------

func _create_hotbar(canvas: Node) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	canvas.add_child(bar)

	for slot in [1, 2, 3]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.08, 0.1, 0.75)
		style.set_border_width_all(2)
		style.border_color = Color(0.3, 0.3, 0.35)

		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(54.0, 54.0)
		panel.add_theme_stylebox_override("panel", style)
		bar.add_child(panel)

		var holder := Control.new()
		panel.add_child(holder)

		var icon := TextureRect.new()
		icon.texture = SLOT_ICONS[slot]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # keep the pixel art sharp
		holder.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)

		var key_label := _make_hud_label(HORIZONTAL_ALIGNMENT_LEFT)
		key_label.text = str(slot)
		key_label.add_theme_font_size_override("font_size", 12)
		holder.add_child(key_label)
		key_label.position = Vector2(3.0, 0.0)

		var ammo_label := _make_hud_label(HORIZONTAL_ALIGNMENT_RIGHT)
		ammo_label.add_theme_font_size_override("font_size", 12)
		holder.add_child(ammo_label)
		ammo_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 3)
		ammo_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		ammo_label.grow_vertical = Control.GROW_DIRECTION_BEGIN

		_hotbar_slots[slot] = {"panel": panel, "icon": icon, "ammo": ammo_label, "style": style}

	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 12)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN


# Highlights the selected slot, dims empty slots and shows the ammo.
func _update_hotbar() -> void:
	for slot in _hotbar_slots:
		var widgets: Dictionary = _hotbar_slots[slot]
		var owned_weapon: PlayerWeapon = _owned_weapons.get(slot)
		var available: bool = slot == SLOT_SWORD or owned_weapon != null

		(widgets["icon"] as TextureRect).modulate = Color.WHITE if available else Color(1.0, 1.0, 1.0, 0.18)
		(widgets["ammo"] as Label).text = str(owned_weapon.ammo) if owned_weapon != null else ""
		(widgets["style"] as StyleBoxFlat).border_color = Color(1.0, 0.85, 0.3) if slot == current_slot else Color(0.3, 0.3, 0.35)


# --------------------------------------------------
# WORLD
# --------------------------------------------------

# True if a point (plus the player's body) would be inside a house.
func _is_inside_house(point: Vector2) -> bool:
	return HouseColliders.point_blocked(get_tree(), point, 6.0)


func _show_hint(text: String) -> void:
	_hint_text = text
	_hint_left = 1.5

# Standing inside a house, building, container, silo or tree counts as out of bounds.
func _enforce_out_of_bounds() -> void:
	if HouseColliders.point_blocked(get_tree(), global_position):
		global_position = HouseColliders.safe_respawn(get_tree())
		velocity = Vector2.ZERO


# "sprint" is registered in project.godot; this only protects against it being removed there.
func _ensure_input_actions() -> void:
	if InputMap.has_action("sprint"):
		return
	InputMap.add_action("sprint")
	var shift := InputEventKey.new()
	shift.physical_keycode = KEY_SHIFT
	InputMap.action_add_event("sprint", shift)


# Same idea for the weapon slots: keys 1, 2 and 3.
func _ensure_weapon_actions() -> void:
	var keys: Dictionary = {"weapon_1": KEY_1, "weapon_2": KEY_2, "weapon_3": KEY_3}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key_event := InputEventKey.new()
		key_event.physical_keycode = keys[action]
		InputMap.action_add_event(action, key_event)


# Same idea for eating (G) and drinking (B).
func _ensure_need_actions() -> void:
	var keys: Dictionary = {"eat": KEY_G, "drink": KEY_B}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key_event := InputEventKey.new()
		key_event.physical_keycode = keys[action]
		InputMap.action_add_event(action, key_event)


# Same idea for the bottle: right mouse button.
func _ensure_bottle_action() -> void:
	if InputMap.has_action("throw_bottle"):
		return
	InputMap.add_action("throw_bottle")
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("throw_bottle", right_click)


# --------------------------------------------------
# BOTTLE (right mouse button)
# --------------------------------------------------

const BOTTLE_SCENE: PackedScene = preload("res://weapons/bottle.tscn")

func _throw_bottle() -> void:
	if _bottle_cooldown_left > 0.0 or is_defeated or dead:
		return

	var origin: Vector2 = global_position + sprite.position + Vector2(0.0, -2.0)
	var to_mouse: Vector2 = get_global_mouse_position() - origin
	var direction: Vector2 = to_mouse.normalized() if not to_mouse.is_zero_approx() else facing_direction
	var distance: float = clampf(to_mouse.length(), 24.0, bottle_range)

	# Turn toward the target.
	facing_direction = direction
	_facing_turn.face_direction(direction)

	ThrownBottle.launch(
		BOTTLE_SCENE, get_tree(), origin + direction * 6.0, origin + direction * distance,
		bottle_damage * damage_multiplier, bottle_knockback, self
	)
	_bottle_cooldown_left = bottle_cooldown


# --------------------------------------------------
# UPGRADES (bought in the menu that opens at the start of a wave)
# --------------------------------------------------

func get_upgrade_level(id: StringName) -> int:
	return int(upgrade_levels.get(id, 0))


func get_upgrade_cost(id: StringName) -> int:
	var def: Dictionary = UpgradeCatalog.get_def(id)
	if def.is_empty():
		return 0
	return UpgradeCatalog.cost_for(def, get_upgrade_level(id))


## Buys the next level of an upgrade with coins. Returns true on success.
func buy_upgrade(id: StringName) -> bool:
	var def: Dictionary = UpgradeCatalog.get_def(id)
	if def.is_empty():
		return false

	var level: int = get_upgrade_level(id)
	if level >= int(def["max"]):
		return false

	var cost: int = UpgradeCatalog.cost_for(def, level)
	if get_item_count(&"coin") < cost:
		return false

	take_from_inventory(&"coin", cost)
	upgrade_levels[id] = level + 1
	_apply_upgrade(id)
	return true


func _apply_upgrade(id: StringName) -> void:
	match id:
		&"max_health":
			max_health += 20.0
			health = minf(health + 20.0, max_health)
		&"max_stamina":
			max_stamina += 20.0
			stamina = minf(stamina + 20.0, max_stamina)
		&"health_regen":
			_health_regen_bonus += 1.0
		&"stamina_regen":
			_stamina_regen_bonus += 2.0
		&"move_speed":
			speed += _base_speed * 0.08


# --------------------------------------------------
# AUTO ATTACK / TELEPORT DAMAGE
# --------------------------------------------------

# Nearest enemy whose center is inside the sword's reach (null if none).
func _find_sword_target() -> Node2D:
	var reach: float = attack_node.attack_range
	var best_squared: float = reach * reach
	var best: Node2D = null

	for node in get_tree().get_nodes_in_group("npc"):
		var enemy := node as Node2D
		if enemy == null:
			continue
		# Auto attack only swings at NPCs that are enemies of the player (or who attacked them), never at peaceful ones.
		if enemy.has_method("is_hostile_to_player") and not enemy.call("is_hostile_to_player") and not enemy.call("has_grudge_against", self):
			continue
		var distance_squared: float = global_position.distance_squared_to(enemy.global_position)
		if distance_squared <= best_squared:
			best_squared = distance_squared
			best = enemy
	return best


# The teleport hurts everything within teleport_radius of the arrival point.
func _teleport_blast(center: Vector2) -> void:
	Fx.teleport_blast(get_tree(), center, teleport_radius)

	var victims: Array[Node2D] = HitDetection.targets_in_arc(
		get_tree(), &"npc", center, Vector2.RIGHT, teleport_radius, 360.0
	)
	for enemy in victims:
		if not enemy.has_method("take_hit"):
			continue
		var direction: Vector2 = (enemy.global_position - center).normalized()
		if direction.is_zero_approx():
			direction = Vector2.from_angle(randf() * TAU)
		enemy.take_hit(HitInfo.create(teleport_damage * damage_multiplier, self, direction, teleport_knockback))


# --------------------------------------------------
# JUMP EFFECTS
# --------------------------------------------------

# Center of the knockback zone (on the ground, where the player takes off).
func _jump_ground_position() -> Vector2:
	if jump_attack_area != null:
		return jump_attack_area.global_position
	return global_position + Vector2(0.0, 1.0)


# Radius of the jump's knockback / damage zone, read from its collision shape, so the effect
# always matches the zone even if the shape is edited.
func _jump_zone_radius() -> float:
	if jump_attack_area != null:
		for child in jump_attack_area.get_children():
			var shape_node := child as CollisionShape2D
			if shape_node == null:
				continue
			var circle := shape_node.shape as CircleShape2D
			if circle != null:
				return circle.radius * shape_node.global_scale.x
	return 15.0


# Ground shadow while the player is in the air; it shrinks as the player rises.
func _draw() -> void:
	if not is_jumping:
		return

	var lifted: float = visual_start_position.y - player_visual.position.y
	var shrink: float = 1.0 - clampf(lifted / maxf(jump_height, 1.0), 0.0, 1.0) * 0.5
	draw_set_transform(visual_start_position + Vector2(0.0, 7.0), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 6.0 * shrink, Color(0.0, 0.0, 0.0, 0.3))


# --------------------------------------------------
# TELEPORT ANIMATION
# --------------------------------------------------

# Step 1 (OUT): the character is sucked into the center of its sprite.
# Step 2: it is moved to the target. Step 3 (IN): the same animation plays backwards there.
func _start_teleport(target: Vector2) -> void:
	_cancel_sword_swing()
	_tp_phase = TeleportPhase.OUT
	_tp_time = 0.0
	_tp_target = target
	velocity = Vector2.ZERO
	can_ability1 = false
	start_teleport_cooldown()
	if _gun_overlay != null:
		_gun_overlay.visible = false
	Fx.teleport_suck(get_tree(), global_position + sprite.position)


func _tick_teleport(delta: float) -> void:
	_tp_time += delta

	if _tp_phase == TeleportPhase.OUT:
		var progress: float = clampf(_tp_time / maxf(teleport_out_time, 0.01), 0.0, 1.0)
		_apply_teleport_pose(progress)
		if progress >= 1.0:
			global_position = _tp_target
			_tp_phase = TeleportPhase.IN
			_tp_time = 0.0
			_teleport_blast(_tp_target)  # the arrival damages enemies around the target
	else:
		# The same pose, played backwards.
		var progress_in: float = clampf(_tp_time / maxf(teleport_in_time, 0.01), 0.0, 1.0)
		_apply_teleport_pose(1.0 - progress_in)
		if progress_in >= 1.0:
			_tp_phase = TeleportPhase.NONE
			sprite.scale = _base_sprite_scale
			sprite.rotation = 0.0


# amount 0 = normal, 1 = sucked into a point (shrunk and spun).
func _apply_teleport_pose(amount: float) -> void:
	var size_factor: float = maxf(1.0 - amount * amount, 0.02)
	sprite.scale = _base_sprite_scale * size_factor
	sprite.rotation = amount * TAU
