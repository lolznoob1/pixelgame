extends Node2D
class_name RarityBadge
## Draws the rarity name above an enemy. Uses _draw() instead of a Label node,
## which is much cheaper with hundreds of enemies on screen.

# Text is drawn at FONT_SIZE and scaled down so it stays crisp under the camera zoom.
const FONT_SIZE: int = 24
const TEXT_SCALE: float = 0.22

## The enemy's own setting (NpcCharacter.show_rarity_label). The developer menu can hide all badges.
var enabled_by_owner: bool = true

var _text: String = ""
var _color: Color = Color.WHITE


func _process(_delta: float) -> void:
	var wanted: bool = enabled_by_owner and DevSettings.show_rarity_labels
	if visible != wanted:
		visible = wanted


func setup(tier: int) -> void:
	_text = Rarity.display_name(tier)
	_color = Rarity.color(tier)
	queue_redraw()


func _draw() -> void:
	if _text.is_empty():
		return

	var font: Font = ThemeDB.fallback_font
	var text_size: Vector2 = font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)

	# Centered on the node, baseline at y = 0.
	draw_set_transform(Vector2(-text_size.x * TEXT_SCALE * 0.5, 0.0), 0.0, Vector2(TEXT_SCALE, TEXT_SCALE))
	draw_string_outline(font, Vector2.ZERO, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 8, Color.BLACK)
	draw_string(font, Vector2.ZERO, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, _color)
