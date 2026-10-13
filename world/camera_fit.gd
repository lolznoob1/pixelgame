extends Camera2D
class_name CameraFit
## Fits the camera to the screen so the pixel art stays sharp at any resolution (1080p, 1440p, 4K, ultrawide).
##
## The zoom is chosen so that ONE art pixel is a whole number of screen pixels (7 at 1080p, 9 at 1440p,
## 14 at 4K), which keeps the edges crisp, and so that about `target_visible_height` world pixels are visible
## vertically (the same view as the old fixed zoom of 4.21 at 648p). Wider screens (21:9, 32:9) show more of the
## world to the sides, they never stretch the picture.
##
## It works with the project's stretch mode (canvas_items, aspect expand) and re-fits when the window changes
## (fullscreen toggle, resizing).

## How many world pixels should be visible from the top to the bottom of the screen.
@export var target_visible_height: float = 154.0
@export var min_pixel_scale: int = 3
@export var max_pixel_scale: int = 24


func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()


func _fit() -> void:
	var screen_height: float = float(get_window().size.y)
	var canvas_height: float = get_viewport().get_visible_rect().size.y
	if screen_height <= 0.0 or canvas_height <= 0.0:
		return

	# Screen pixels per canvas unit (the stretch factor of canvas_items / expand).
	var stretch: float = screen_height / canvas_height
	# Whole screen pixels per art pixel.
	var pixel_scale: int = clampi(roundi(screen_height / target_visible_height), min_pixel_scale, max_pixel_scale)

	zoom = Vector2.ONE * (float(pixel_scale) / stretch)
