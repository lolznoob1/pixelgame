extends Node2D

@onready var player = $player
@onready var game_over_ui = $GameOverUI

func _ready() -> void:
	game_over_ui.hide()
	player.died.connect(_on_player_died)

	# A new game: the relations and the faction inventories start from scratch. (Things set in the developer menu,
	# like item prices, stay.)
	Relations.reset()
	FactionInventories.reset()

	# The upgrade and shop window (key T). It always exists; the wave event gives the shop new offers every wave.
	var upgrade_menu := UpgradeMenu.new()
	upgrade_menu.name = "UpgradeMenu"
	upgrade_menu.player = player
	add_child(upgrade_menu)
	upgrade_menu.start_wave(1, 0)

	# ESC menu (resume / options / exit / developer). Built in code.
	var pause_menu := PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)

func _on_player_died() -> void:
	game_over_ui.show()
	get_tree().paused = true

func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
