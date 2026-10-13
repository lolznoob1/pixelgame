extends Control
class_name CoinCounter
## The coin counter of the HUD: a coin the size of the bottle gauge, then "x" and the amount in a chunky
## orange pixel font. The coin spins once every time the amount goes up (a coin was picked up).
##
## Art: assets/ui/coin_spin.png (12 frames of 16 x 22) and assets/ui/coin_digits.png (digits 0-9 and "x", 12 x 16
## each), both made by tools/make_coin_art.py. Use other textures with the same layout for another look.

const COIN_SHEET: Texture2D = preload("res://assets/ui/coin_spin.png")
const DIGIT_SHEET: Texture2D = preload("res://assets/ui/coin_digits.png")
const COIN_W: int = 16
const COIN_H: int = 22
const COIN_FRAMES: int = 12
const GLYPH_W: int = 12
const GLYPH_H: int = 16
const GLYPHS: String = "0123456789x"

## Screen pixels per art pixel (3 = the same scale as the bottle gauge, so the coin is exactly as big as the bottle).
@export var pixel_scale: int = 3
## Frames per second of the spin (12 frames = one turn).
@export var spin_fps: float = 24.0

var _count: int = 0
var _spin_time: float = -1.0  # < 0: not spinning
var _pop: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # keep the pixel art sharp
	_update_size()


## Sets the amount. If it went UP the coin spins (and the digits hop a little).
func set_count(value: int) -> void:
	if value == _count:
		return
	if value > _count:
		spin()
		_pop = 1.0
	_count = value
	_update_size()
	queue_redraw()


## Starts the spin (a spin that is already running starts over, so picking up coins quickly keeps it turning).
func spin() -> void:
	_spin_time = 0.0
	queue_redraw()


func _update_size() -> void:
	var glyph_count: int = 1 + str(_count).length()  # the "x" and the digits
	var width: int = COIN_W + 2 + glyph_count * (GLYPH_W - 1) + 1
	custom_minimum_size = Vector2(width, COIN_H) * float(pixel_scale)


func _process(delta: float) -> void:
	var changed: bool = false
	if _spin_time >= 0.0:
		_spin_time += delta
		if _spin_time * spin_fps >= float(COIN_FRAMES):
			_spin_time = -1.0
		changed = true
	if _pop > 0.0:
		_pop = maxf(_pop - delta * 6.0, 0.0)
		changed = true
	if changed:
		queue_redraw()


func _draw() -> void:
	var unit: float = float(pixel_scale)

	# the coin
	var frame: int = 0 if _spin_time < 0.0 else mini(int(_spin_time * spin_fps), COIN_FRAMES - 1)
	draw_texture_rect_region(
		COIN_SHEET,
		Rect2(Vector2.ZERO, Vector2(COIN_W, COIN_H) * unit),
		Rect2(frame * COIN_W, 0, COIN_W, COIN_H)
	)

	# "x" and the amount (they hop up a little when the amount changes)
	var text: String = "x" + str(_count)
	var x: float = float(COIN_W + 2) * unit
	var y: float = float(COIN_H - GLYPH_H) * 0.5 * unit - _pop * 2.0 * unit
	for i in text.length():
		var index: int = GLYPHS.find(text[i])
		if index < 0:
			continue
		draw_texture_rect_region(
			DIGIT_SHEET,
			Rect2(Vector2(x, y), Vector2(GLYPH_W, GLYPH_H) * unit),
			Rect2(index * GLYPH_W, 0, GLYPH_W, GLYPH_H)
		)
		x += float(GLYPH_W - 1) * unit
