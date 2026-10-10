
extends Node2D

@onready var player = $player
@onready var game_over_ui = $GameOverUI

func _ready() -> void:
	game_over_ui.hide()
	player.oxygen_depleted.connect(_on_oxygen_depleted)

func _on_oxygen_depleted() -> void:
	game_over_ui.show()
	get_tree().paused = true

func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
