extends Control
class_name AbilityGauge
## A cooldown gauge drawn as an icon that fills up: the "empty" texture is always drawn, the "full" texture is
## revealed from the bottom up as the cooldown runs down. When it is full again the icon pops once.
##
## It is not tied to the bottle: give it any two textures of the same size (and the rows where the fill is) and it
## works for another character's secondary ability. The player sets the textures through its exports
## (secondary_icon_empty / secondary_icon_full / secondary_fill_top / secondary_fill_bottom).

@export var icon_empty: Texture2D
@export var icon_full: Texture2D
## First texture row that can be filled (the top of the water) ...
@export var fill_top: int = 0
## ... and the row after the last one (the bottom). -1 = the bottom of the texture.
@export var fill_bottom: int = -1
## Screen pixels per texture pixel.
@export var pixel_scale: int = 3
## Optional foam on the surface of the liquid (the beer): transparent = none. It is drawn over `foam_rows`
## texture rows at the water line, between the texture columns `foam_x0` and `foam_x1` (inclusive).
@export var foam_color: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var foam_rows: int = 2
@export var foam_x0: int = 0
@export var foam_x1: int = 0

var _fill: float = 1.0
var _pop: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # keep the pixel art sharp
	_update_size()


## Sets the textures (e.g. when the character changes).
func set_icons(empty: Texture2D, full: Texture2D, top: int, bottom: int) -> void:
	icon_empty = empty
	icon_full = full
	fill_top = top
	fill_bottom = bottom
	_update_size()
	queue_redraw()


## 0 = empty (just used), 1 = full (ready).
func set_fill(value: float) -> void:
	var new_fill: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(new_fill, _fill):
		return
	if new_fill >= 1.0 and _fill < 1.0:
		_pop = 1.0  # ready again: a little pop
	_fill = new_fill
	queue_redraw()


func _update_size() -> void:
	if icon_empty != null:
		custom_minimum_size = icon_empty.get_size() * float(pixel_scale)


func _process(delta: float) -> void:
	if _pop > 0.0:
		_pop = maxf(_pop - delta * 4.0, 0.0)
		queue_redraw()


func _draw() -> void:
	if icon_empty == null:
		return

	var texture_size: Vector2 = icon_empty.get_size()
	var unit: float = float(pixel_scale)
	var pop_scale: float = 1.0 + _pop * 0.25

	# Draw around the center, so the pop grows from the middle.
	draw_set_transform(size * 0.5, 0.0, Vector2(pop_scale, pop_scale))
	var origin: Vector2 = -texture_size * unit * 0.5
	draw_texture_rect(icon_empty, Rect2(origin, texture_size * unit), false)

	if icon_full == null or _fill <= 0.0:
		return

	var bottom: int = fill_bottom if fill_bottom >= 0 else int(texture_size.y)
	var water_height: float = float(bottom - fill_top)
	# Texture row of the water surface (whole texture pixels, so the pixel art stays crisp).
	var surface_row: float = roundf(float(fill_top) + (1.0 - _fill) * water_height)

	var source := Rect2(0.0, surface_row, texture_size.x, texture_size.y - surface_row)
	var target := Rect2(origin + Vector2(0.0, surface_row * unit), Vector2(texture_size.x * unit, source.size.y * unit))
	draw_texture_rect_region(icon_full, target, source)

	# Foam on top of the liquid.
	if foam_color.a > 0.0:
		var rows: int = mini(foam_rows, bottom - int(surface_row))
		for i in rows:
			var shade: Color = foam_color if i == 0 else foam_color.darkened(0.1)
			draw_rect(Rect2(
				origin + Vector2(float(foam_x0) * unit, (surface_row + float(i)) * unit),
				Vector2(float(foam_x1 - foam_x0 + 1) * unit, unit)
			), shade)

	# A slightly lighter line at the water surface.
	if _fill < 1.0 and foam_color.a <= 0.0:
		draw_texture_rect_region(
			icon_full,
			Rect2(target.position, Vector2(target.size.x, unit)),
			Rect2(0.0, surface_row, texture_size.x, 1.0),
			Color(1.25, 1.3, 1.4, 1.0)
		)
