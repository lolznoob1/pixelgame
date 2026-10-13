extends Sprite2D
class_name RarityGlow
## A soft colored light on the ground under an enemy, in the color of its rarity.
## The stronger the rarity, the larger and stronger the glow.

const ALPHA_BY_TIER: Array[float] = [0.30, 0.40, 0.50, 0.60, 0.72]

# One radial gradient texture shared by all enemies.
static var _shared_texture: GradientTexture2D


static func _get_texture() -> GradientTexture2D:
	if _shared_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))  # middle: opaque
		gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))  # edge: transparent

		var gradient_texture := GradientTexture2D.new()
		gradient_texture.gradient = gradient
		gradient_texture.fill = GradientTexture2D.FILL_RADIAL
		gradient_texture.fill_from = Vector2(0.5, 0.5)
		gradient_texture.fill_to = Vector2(1.0, 0.5)
		gradient_texture.width = 32
		gradient_texture.height = 32
		_shared_texture = gradient_texture
	return _shared_texture


## `feet_position`: local position of the glow's center. `size_scale`: the enemy's sprite scale.
func setup(tier: int, feet_position: Vector2, size_scale: float) -> void:
	var clamped_tier: int = Rarity.clamp_tier(tier)

	texture = _get_texture()
	var color: Color = Rarity.color(clamped_tier)
	color.a = ALPHA_BY_TIER[clamped_tier]
	modulate = color

	position = feet_position
	scale = Vector2(0.95, 0.65) * size_scale * (1.0 + 0.08 * float(clamped_tier))
	z_index = -1  # behind the enemy, above the ground


func _process(_delta: float) -> void:
	var wanted: bool = DevSettings.show_rarity_glow
	if visible != wanted:
		visible = wanted
