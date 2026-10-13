extends Control
class_name StageGauge
## An icon that changes through a strip of frames as a value goes down. Used for the hunger: the sandwich with more
## and more bites taken out of it. Frame 0 = full, the last frame = empty (assets/ui/sandwich_stages.png, 11 frames).
## Blinks red while `alert` is on (starving).

@export var strip: Texture2D
@export var frame_count: int = 11
@export var frame_width: int = 16
@export var frame_height: int = 22
## Screen pixels per texture pixel (3 = the same scale as the bottle gauge).
@export var pixel_scale: int = 3

var _fraction: float = 1.0
var _alert: bool = false
var _alert_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # keep the pixel art sharp
	custom_minimum_size = Vector2(frame_width, frame_height) * float(pixel_scale)


## 1 = full, 0 = empty.
func set_fraction(value: float) -> void:
	var new_fraction: float = clampf(value, 0.0, 1.0)
	if _frame_for(new_fraction) != _frame_for(_fraction):
		queue_redraw()
	_fraction = new_fraction


func set_alert(on: bool) -> void:
	_alert = on
	if not on:
		modulate = Color.WHITE


# Each 10 % of the value takes one more bite: 100 = frame 0, 99..90 = frame 1, ..., 0 = the last frame.
func _frame_for(fraction: float) -> int:
	return clampi(ceili((1.0 - fraction) * float(frame_count - 1) - 0.0001), 0, frame_count - 1)


func _process(delta: float) -> void:
	if _alert:
		_alert_time += delta
		var pulse: float = 0.5 + 0.5 * sin(_alert_time * 8.0)
		modulate = Color(1.0, 1.0 - 0.6 * pulse, 1.0 - 0.6 * pulse)


func _draw() -> void:
	if strip == null:
		return
	var frame: int = _frame_for(_fraction)
	draw_texture_rect_region(
		strip,
		Rect2(Vector2.ZERO, Vector2(frame_width, frame_height) * float(pixel_scale)),
		Rect2(frame * frame_width, 0, frame_width, frame_height)
	)
