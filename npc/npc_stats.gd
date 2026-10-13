# npc_stats.gd
extends Resource
class_name NpcStats

## How the enemy gets to the player.
enum Approach {
	DIRECT,         ## Straight line to the player.
	ENCIRCLE,       ## Spreads around the player before closing in.
	KEEP_DISTANCE,  ## Stays between min_distance and max_distance (ranged enemies).
}

@export var display_name: String = "NPC"

@export_group("Identity")
## The faction this kind of NPC belongs to. (The population can give an NPC another faction when it spawns it.)
@export var faction: Faction.Id = Faction.Id.CIVILIAN
## Not empty = a UNIQUE NPC: always neutral to every faction, its own relation with the player (see Relations).
@export var unique_id: StringName = &""
## The relation points the player starts with this unique NPC (-100 to 100).
@export_range(-100, 100) var unique_start_points: int = 0
## Size class: decides how fast the hunger runs down (light 2, medium 3, heavy 4, special 0 per minute).
@export var npc_type: NpcType.Type = NpcType.Type.MEDIUM

@export_group("Needs and goals")
## A new NPC starts with a hunger value between this and 100.
@export_range(0.0, 100.0) var start_hunger_min: float = 60.0
## The conditions that make this NPC happy. Empty = the default set (see NpcGoal.default_set()).
@export var goals: Array[NpcGoal] = []
## How far it notices NPCs it is hostile to (the player is noticed from the detection range of the NPC).
@export var npc_detection_range: float = 160.0

@export_group("Inventory")
## What an NPC carries when it spawns: random between x and y. It is dropped when the NPC dies.
@export var start_coins: Vector2i = Vector2i(0, 6)
@export var start_food: Vector2i = Vector2i(0, 1)

@export_group("Combat")
@export var max_health: float = 30.0
@export var contact_damage: float = 1.0
## Damage (health) of one attack hit on the player.
@export var attack_damage: float = 5.0
## Incoming damage is multiplied by 100 / (100 + armor): 10 armor = -9 %, 100 armor = -50 %.
@export var armor: float = 5.0
@export var attack_cooldown: float = 1.0
## Telegraph time before an attack lands / a throw is released.
@export var attack_windup: float = 0.25
## 0.0 = full knockback, 1.0 = immune
@export_range(0.0, 1.0) var knockback_resistance: float = 0.0

@export_group("Approach")
@export var approach: Approach = Approach.ENCIRCLE
## Only used by KEEP_DISTANCE: back away when closer, step in when farther.
@export var min_distance: float = 30.0
@export var max_distance: float = 80.0

@export_group("Ranged Attack")
## If set, the attack throws this scene (an NpcProjectile) instead of a melee hit.
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 140.0
@export var projectile_lifetime: float = 2.0
## Push distance when the projectile hits the player. 0 = none (the shoe doesn't knock back).
## Kept as a setting so future projectiles can.
@export var projectile_knockback: float = 0.0
## false: the projectile only deals damage and does not stun the player (the shoe).
@export var projectile_stun: bool = false
@export var throw_animation: StringName = &"throw"
## Animation frame at which the projectile leaves the hand.
@export var throw_release_frame: int = 2

@export_group("Turning")
## 8-direction sprites (see tools/make_directions.py). Empty = the enemy just flips left/right.
@export var direction_sheet: DirectionalSheet

@export_group("Death")
## Death animations (8 frames of 48 x 48 side by side). Which one plays depends on the class of the weapon
## that killed the enemy (see WeaponClass):
## heavy weapons (rocket launcher): the enemy explodes into red goo.
@export var death_sheet_heavy: Texture2D
## light weapons (sword, AK-47): the enemy is shot down, sprays blood and leaves a corpse.
@export var death_sheet_light: Texture2D

@export_group("Drops")
## Optional: overrides the drop table of the enemy's rarity (see RarityDrops) when it dies.
@export var death_drops: DropTable
## Rolled when the enemy is hit but survives (hurt state).
@export var hurt_drops: DropTable

@export_group("Movement")
## Multiplies the speed set by the behavior (Wander/Chase),
## so you don't have to edit those scripts.
@export var speed_multiplier: float = 1.0

@export_group("Animation")
## Leave empty to keep the SpriteFrames already set in the scene.
@export var sprite_frames: SpriteFrames
@export var idle_animation: StringName = &"idle"
@export var walk_animation: StringName = &"walk"
@export var hurt_animation: StringName = &"hurt"
@export var death_animation: StringName = &"death"
@export var sprite_scale: Vector2 = Vector2.ONE
