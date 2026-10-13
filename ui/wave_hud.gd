extends CanvasLayer
class_name WaveHud
## Top-right corner: an hourglass that shows the progress of the current wave.
##   - The sand runs from the top to the bottom chamber during the wave.
##   - When it has run out, the glass turns around (the end of this wave / the start of the next).
## The turn takes a share of the wave duration, so everything scales if the wave duration changes.
## Created by the WaveEvent when it starts and removed when it ends: the hourglass only exists while the wave event is active.

@export var pixel_scale: int = 3
## The turn takes this share of the wave duration (clamped).
@export var flip_fraction: float = 0.06
@export var min_flip_time: float = 0.6
@export var max_flip_time: float = 3.0
## Shows the wave counter under the hourglass.
@export var show_wave_number: bool = true

var _glass: HourglassView
var _number_label: Label


func _ready() -> void:
	layer = 10

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	add_child(box)

	_glass = HourglassView.new()
	_glass.pixel_scale = pixel_scale
	box.add_child(_glass)

	_number_label = Label.new()
	_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number_label.add_theme_font_size_override("font_size", 22)
	_number_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_number_label.add_theme_constant_override("outline_size", 5)
	_number_label.visible = show_wave_number
	box.add_child(_number_label)

	# Pin to the top-right corner; it grows toward the left if it ever gets wider.
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN


## A new wave started. The rank only tints the hourglass's wooden caps.
func show_wave(wave: int, rank_tier: int) -> void:
	_glass.set_accent(Rarity.color(rank_tier))
	_number_label.text = "WAVE %d" % wave


## Called every frame with the time into the current wave and the wave duration.
func set_clock(elapsed: float, duration: float) -> void:
	var flip_time: float = get_flip_time(duration)
	var fall_time: float = maxf(duration - flip_time, 0.001)

	if elapsed < fall_time:
		_glass.set_state(elapsed / fall_time, 0.0)
	else:
		# The sand has all run down: turn the glass by 180 degrees.
		var turn: float = clampf((elapsed - fall_time) / maxf(flip_time, 0.001), 0.0, 1.0)
		_glass.set_state(1.0, smoothstep(0.0, 1.0, turn) * PI)


## How long the turn takes for a given wave duration (never more than half of the wave).
func get_flip_time(duration: float) -> float:
	return minf(clampf(duration * flip_fraction, min_flip_time, max_flip_time), duration * 0.5)
