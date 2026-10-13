extends Node2D
class_name FactionBadge
## The faction of an NPC as a small label above it, colored by how the NPC stands to the player:
## green = friendly, gray = neutral, red = hostile. Unique NPCs show their name. Drawn with _draw() (cheap, like
## RarityBadge). The developer menu (General) can hide all of them.

const FONT_SIZE: int = 24
const TEXT_SCALE: float = 0.2
const COLORS: Dictionary = {
	Relation.Level.FRIENDLY: Color(0.45, 0.95, 0.5),
	Relation.Level.NEUTRAL: Color(0.82, 0.84, 0.88),
	Relation.Level.HOSTILE: Color(1.0, 0.35, 0.3),
}

var _npc: NpcCharacter
var _text: String = ""
var _color: Color = Color.WHITE
var _timer: float = 0.0


func setup(npc: NpcCharacter) -> void:
	_npc = npc
	_timer = randf() * 0.4
	_refresh()


func _process(delta: float) -> void:
	var wanted: bool = DevSettings.show_faction_labels
	if visible != wanted:
		visible = wanted
	if not wanted or not is_instance_valid(_npc):
		return
	# The relation can change at any time (the player attacks somebody, the event starts): look again now and then.
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.4
		_refresh()


func _refresh() -> void:
	if not is_instance_valid(_npc):
		return
	var unique_id: StringName = _npc.unique_id
	var text: String = String(unique_id) if unique_id != &"" else Faction.display_name(_npc.faction)
	var color: Color = COLORS[Relations.npc_to_player(_npc)]
	if text != _text or color != _color:
		_text = text
		_color = color
		queue_redraw()


func _draw() -> void:
	if _text.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var text_size: Vector2 = font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	draw_set_transform(Vector2(-text_size.x * TEXT_SCALE * 0.5, 0.0), 0.0, Vector2(TEXT_SCALE, TEXT_SCALE))
	draw_string_outline(font, Vector2.ZERO, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 8, Color.BLACK)
	draw_string(font, Vector2.ZERO, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, _color)
