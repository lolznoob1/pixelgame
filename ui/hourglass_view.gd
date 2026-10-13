extends Control
class_name HourglassView
## A pixel-art hourglass drawn with rectangles. `fall` is how much of the sand has run down
## (0 = top full, 1 = bottom full); `angle` turns the whole glass.
##
## The art is point-symmetric: the glass turned by 180 degrees with the sand at the bottom looks
## exactly like the unturned glass with the sand at the top, so the turn at the end of a wave
## flows seamlessly into the next one.

const ART_W: int = 13
const ART_H: int = 26
const CENTER_X: int = 6
## Inner half-widths of the glass rows y = 2..11 (top chamber). The bottom chamber is the point mirror.
const TOP_HALF: Array[int] = [5, 5, 4, 4, 3, 3, 2, 2, 1, 1]

const OUTLINE: Color = Color(0.16, 0.12, 0.2)
const GLASS_FILL: Color = Color(0.8, 0.92, 1.0, 0.16)
const GLASS_SHINE: Color = Color(1.0, 1.0, 1.0, 0.55)
const SAND: Color = Color(0.93, 0.78, 0.42)
const SAND_DARK: Color = Color(0.78, 0.6, 0.3)
const WOOD_LIGHT: Color = Color(0.62, 0.42, 0.24)
const WOOD_DARK: Color = Color(0.38, 0.25, 0.15)

## Screen pixels per art pixel.
@export var pixel_scale: int = 3

var _fall: float = 0.0
var _angle: float = 0.0
var _accent: Color = Color.WHITE
var _clock: float = 0.0


func _ready() -> void:
	# Square, so the glass has room to turn.
	custom_minimum_size = Vector2(30.0, 30.0) * float(pixel_scale)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(fall: float, angle: float) -> void:
	_fall = clampf(fall, 0.0, 1.0)
	_angle = angle
	queue_redraw()


## Tints the wooden caps (used for the current enemy rank).
func set_accent(color: Color) -> void:
	_accent = color
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	# The trickle animates while sand is running.
	if _fall > 0.0 and _fall < 1.0:
		queue_redraw()


# --------------------------------------------------
# GEOMETRY
# --------------------------------------------------

# Inner half-width of the glass at row y (rows 2..23).
func _half_at(y: int) -> int:
	if y >= 2 and y <= 11:
		return TOP_HALF[y - 2]
	if y >= 14 and y <= 23:
		return TOP_HALF[23 - y]
	return 0  # the neck


# Rows of one chamber ordered the way sand fills / empties it.
func _top_rows() -> Array[int]:
	var rows: Array[int] = []
	for y in range(11, 1, -1):  # from the neck up to the top
		rows.append(y)
	return rows


func _bottom_rows() -> Array[int]:
	var rows: Array[int] = []
	for y in range(23, 13, -1):  # from the bottom up to the neck
		rows.append(y)
	return rows


func _area_of(rows: Array[int]) -> int:
	var total: int = 0
	for y in rows:
		total += _half_at(y) * 2 + 1
	return total


# Sand rows for `target_area` pixels, filling `rows` in order. Returns (y, x0, width) runs.
# A partly filled row keeps an odd width, so it stays centered.
func _fill_rows(rows: Array[int], target_area: int) -> Array[Vector3i]:
	var runs: Array[Vector3i] = []
	var remaining: int = target_area
	for y in rows:
		if remaining <= 0:
			break
		var half: int = _half_at(y)
		var width: int = half * 2 + 1
		if remaining >= width:
			runs.append(Vector3i(y, CENTER_X - half, width))
			remaining -= width
		else:
			var partial: int = remaining if remaining % 2 == 1 else remaining - 1
			if partial > 0:
				runs.append(Vector3i(y, CENTER_X - (partial >> 1), partial))
			break
	return runs


# Darker grains. Folded coordinates, so the pattern is the same after a 180 degree turn.
func _is_grain(x: int, y: int) -> bool:
	var folded_x: int = mini(x, ART_W - 1 - x)
	var folded_y: int = mini(y, ART_H - 1 - y)
	return (folded_x * 3 + folded_y * 5) % 7 == 0


# --------------------------------------------------
# DRAWING
# --------------------------------------------------

# One art pixel (or a horizontal run of them). Slightly oversized so turned rectangles show no seams.
func _px(x: int, y: int, color: Color, width: int = 1) -> void:
	draw_rect(Rect2(float(x) - 6.5 - 0.01, float(y) - 13.0 - 0.01, float(width) + 0.02, 1.02), color)


func _draw() -> void:
	draw_set_transform(size * 0.5, _angle, Vector2(float(pixel_scale), float(pixel_scale)))

	var top_rows: Array[int] = _top_rows()
	var bottom_rows: Array[int] = _bottom_rows()
	var total: int = _area_of(top_rows)

	var top_runs: Array[Vector3i] = _fill_rows(top_rows, roundi((1.0 - _fall) * float(total)))
	var bottom_runs: Array[Vector3i] = _fill_rows(bottom_rows, roundi(_fall * float(total)))

	# --- glass interior ---
	for y in range(2, 24):
		var half: int = _half_at(y)
		_px(CENTER_X - half, y, GLASS_FILL, half * 2 + 1)

	# --- sand ---
	for run in top_runs + bottom_runs:
		for x in range(run.y, run.y + run.z):
			_px(x, run.x, SAND_DARK if _is_grain(x, run.x) else SAND)

	# --- falling stream through the neck, from the top chamber down to the pile ---
	if not top_runs.is_empty() and _fall > 0.0 and _fall < 1.0:
		var surface_y: int = 24 if bottom_runs.is_empty() else bottom_runs.back().x
		var phase: int = int(_clock * 14.0) % 3
		for y in range(12, surface_y):
			if (y + phase) % 3 != 0:
				_px(CENTER_X, y, SAND)

	# --- glass outline ---
	for y in range(2, 24):
		var half: int = _half_at(y)
		_px(CENTER_X - half - 1, y, OUTLINE)
		_px(CENTER_X + half + 1, y, OUTLINE)

	# --- shine (and its point mirror, so the glass is symmetric) ---
	for y in range(3, 6):
		var shine_x: int = CENTER_X - _half_at(y)
		_px(shine_x, y, GLASS_SHINE)
		_px(ART_W - 1 - shine_x, ART_H - 1 - y, GLASS_SHINE)

	# --- wooden caps, tinted with the accent color ---
	var light: Color = WOOD_LIGHT.lerp(_accent, 0.45)
	var dark: Color = WOOD_DARK.lerp(_accent, 0.3)
	_px(0, 0, light, ART_W)
	_px(0, 1, dark, ART_W)
	_px(0, 24, dark, ART_W)
	_px(0, 25, light, ART_W)
