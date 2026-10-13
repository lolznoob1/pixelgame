extends Node2D
class_name RingFlash
## A ring that expands and fades: the teleport blast radius, the air pressure wave of a jump.

@export var max_radius: float = 20.0
@export var duration: float = 0.25
@export var color: Color = Color(0.6, 0.9, 1.0, 0.9)
@export var line_width: float = 2.0
## Seconds to wait before the ring appears (lets a second ring trail the first).
@export var delay: float = 0.0
## Fills the inside of the ring with a faint disc.
@export var fill: bool = true

var _age: float = 0.0


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= delay + duration:
		queue_free()


func _draw() -> void:
	var elapsed: float = _age - delay
	if elapsed < 0.0:
		return

	var progress: float = clampf(elapsed / duration, 0.0, 1.0)
	var radius: float = lerpf(4.0, max_radius, progress)

	var ring_color: Color = color
	ring_color.a *= 1.0 - progress

	if fill:
		draw_circle(Vector2.ZERO, radius, Color(ring_color.r, ring_color.g, ring_color.b, ring_color.a * 0.25))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, ring_color, line_width)
