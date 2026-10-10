# enemy_stats.gd
extends Resource
class_name EnemyStats

@export var display_name: String = "Enemy"

@export_group("Combat")
@export var max_health: float = 30.0
@export var contact_damage: float = 1.0
## 0.0 = full knockback, 1.0 = immune
@export_range(0.0, 1.0) var knockback_resistance: float = 0.0

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
