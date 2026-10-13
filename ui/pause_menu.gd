extends CanvasLayer
class_name PauseMenu
## ESC menu: Resume, Options, Exit, Developer. Built in code (no scene to maintain).
## Options are saved to user://settings.cfg. The Developer screen edits DevSettings live.

const SETTINGS_PATH: String = "user://settings.cfg"

var _open: bool = false
var _root: Control
var _panel_roots: Array[Control] = []
var _main_panel: Control
var _options_panel: Control
var _dev_panel: Control
var _dev_holder: VBoxContainer
var _fps_label: Label
var _fullscreen_check: CheckBox

# Options
var _fullscreen: bool = false
var _vsync: bool = true
var _volume: float = 1.0
var _show_fps: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # must keep working while the game is paused
	layer = 40
	add_to_group("pause_menu")

	_read_current_settings()
	_load_settings()
	_build_fps_label()
	_build_menu()


func _process(_delta: float) -> void:
	if _show_fps:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func _unhandled_input(event: InputEvent) -> void:
	# F11 switches fullscreen on and off from anywhere.
	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F11:
		_fullscreen = not _fullscreen
		_apply_fullscreen()
		_save_settings()
		if _fullscreen_check != null:
			_fullscreen_check.set_pressed_no_signal(_fullscreen)
		get_viewport().set_input_as_handled()
		return

	if not event.is_action_pressed("ui_cancel"):
		return

	if _open:
		# ESC inside a sub screen goes back; on the main screen it resumes.
		if _main_panel.visible:
			_resume()
		else:
			_show_panel(_main_panel)
		get_viewport().set_input_as_handled()
	elif not get_tree().paused:
		# Paused by something else (upgrade window, game over): not our business.
		_open_menu()
		get_viewport().set_input_as_handled()


func _open_menu() -> void:
	_open = true
	_root.visible = true
	get_tree().paused = true
	_show_panel(_main_panel)


func _resume() -> void:
	_open = false
	_root.visible = false
	get_tree().paused = false


# --------------------------------------------------
# BUILDING
# --------------------------------------------------

func _build_menu() -> void:
	_root = Control.new()
	_root.visible = false
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# --- main ---
	var main: Dictionary = _make_panel("Paused", 360.0)
	_main_panel = main["root"]
	var main_box: VBoxContainer = main["box"]
	_add_button(main_box, "Resume", _resume)
	_add_button(main_box, "Options", _open_options)
	_add_button(main_box, "Exit", _exit_game)
	_add_button(main_box, "Developer", _open_developer)

	# --- options ---
	var options: Dictionary = _make_panel("Options", 560.0)
	_options_panel = options["root"]
	var options_box: VBoxContainer = options["box"]
	_add_check(options_box, "Auto attack (the sword swings at enemies in reach)", GameSettings.auto_attack, _on_auto_attack_toggled)
	_fullscreen_check = _add_check(options_box, "Fullscreen  (F11)", _fullscreen, _on_fullscreen_toggled)
	_add_check(options_box, "VSync", _vsync, _on_vsync_toggled)
	_add_check(options_box, "Show FPS", _show_fps, _on_show_fps_toggled)
	_add_slider(options_box, "Master volume", 0.0, 1.0, 0.05, _volume, 100.0, 0, " %", _on_volume_changed)
	_add_button(options_box, "Back", _open_main)

	# --- developer (content is built when it is opened) ---
	var dev: Dictionary = _make_panel("Developer", 820.0)
	_dev_panel = dev["root"]
	_dev_holder = dev["box"]


# A centered window with a title. Returns {"root": Control, "box": VBoxContainer}.
func _make_panel(title: String, width: float) -> Dictionary:
	var center := CenterContainer.new()
	center.visible = false
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0.0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	box.add_child(title_label)

	_panel_roots.append(center)
	return {"root": center, "box": box}


func _show_panel(panel: Control) -> void:
	for root in _panel_roots:
		root.visible = (root == panel)

	var first: BaseButton = _find_first_button(panel)
	if first != null:
		first.grab_focus()


func _find_first_button(node: Node) -> BaseButton:
	for child in node.get_children():
		if child is BaseButton:
			return child as BaseButton
		var found: BaseButton = _find_first_button(child)
		if found != null:
			return found
	return null


func _add_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 40.0)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _add_check(parent: Node, text: String, value: bool, callback: Callable) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.button_pressed = value
	check.toggled.connect(callback)
	parent.add_child(check)
	return check


## A labeled slider. `display_scale` / `decimals` / `suffix` only affect the shown value.
func _add_slider(
	parent: Node, text: String, min_value: float, max_value: float, step: float,
	value: float, display_scale: float, decimals: int, suffix: String, callback: Callable
) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(300.0, 0.0)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(260.0, 0.0)
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(80.0, 0.0)
	value_label.text = String.num(value * display_scale, decimals) + suffix
	row.add_child(value_label)

	# Connected after the initial value is set, so building the menu changes nothing.
	slider.value_changed.connect(_on_slider_changed.bind(value_label, display_scale, decimals, suffix, callback))
	return slider


func _on_slider_changed(
	value: float, value_label: Label, display_scale: float, decimals: int, suffix: String, callback: Callable
) -> void:
	value_label.text = String.num(value * display_scale, decimals) + suffix
	callback.call(value)


func _add_note(parent: Node, text: String) -> void:
	var note := Label.new()
	note.text = text
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(700.0, 0.0)
	note.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	parent.add_child(note)


func _make_tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title  # the tab title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	return box


# --------------------------------------------------
# DEVELOPER SCREEN
# --------------------------------------------------

func _open_main() -> void:
	_show_panel(_main_panel)


func _open_options() -> void:
	_show_panel(_options_panel)


func _exit_game() -> void:
	get_tree().quit()


func _reset_developer() -> void:
	DevSettings.reset_to_defaults(
		GameEvent.find(get_tree(), &"wave"),
		get_tree().get_first_node_in_group("player")
	)
	_build_developer_content()
	_show_panel(_dev_panel)


func _on_auto_attack_toggled(on: bool) -> void:
	GameSettings.auto_attack = on
	_save_settings()


func _on_fullscreen_toggled(on: bool) -> void:
	_fullscreen = on
	_apply_fullscreen()
	_save_settings()


func _on_vsync_toggled(on: bool) -> void:
	_vsync = on
	_apply_vsync()
	_save_settings()


func _on_show_fps_toggled(on: bool) -> void:
	_show_fps = on
	_fps_label.visible = on
	_save_settings()


func _on_volume_changed(value: float) -> void:
	_volume = value
	_apply_volume()
	_save_settings()


# The slider passes its value first; the bound index / id is appended after it.
func _on_rarity_weight_changed(value: float, index: int) -> void:
	DevSettings.rarity_weights[index] = value


func _on_item_chance_changed(value: float, item_id: StringName) -> void:
	DevSettings.item_chance_mult[item_id] = value


func _open_developer() -> void:
	_build_developer_content()
	_show_panel(_dev_panel)


# (Re)builds everything under the title, so the sliders always show the current values.
func _build_developer_content() -> void:
	# Keep the title (first child), remove the rest.
	var children: Array[Node] = _dev_holder.get_children()
	for i in range(1, children.size()):
		_dev_holder.remove_child(children[i])
		children[i].queue_free()

	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0.0, 340.0)
	_dev_holder.add_child(tabs)

	# ---- General ----
	var general: VBoxContainer = _make_tab(tabs, "General")
	_add_check(general, "Show enemy rarity labels", DevSettings.show_rarity_labels, func(on: bool) -> void: DevSettings.show_rarity_labels = on)
	_add_check(general, "Show colored glow under enemies", DevSettings.show_rarity_glow, func(on: bool) -> void: DevSettings.show_rarity_glow = on)
	_add_check(general, "Show the faction above NPCs", DevSettings.show_faction_labels, func(on: bool) -> void: DevSettings.show_faction_labels = on)

	# ---- Player ----
	var player_tab: VBoxContainer = _make_tab(tabs, "Player")
	_add_note(player_tab, "Regeneration per second. Regeneration upgrades bought in the shop are added on top.")
	_add_slider(player_tab, "Health regeneration", 0.0, 20.0, 0.5, DevSettings.health_regen, 1.0, 1, " /s", func(v: float) -> void: DevSettings.health_regen = v)
	_add_slider(player_tab, "Stamina regeneration", 0.0, 50.0, 1.0, DevSettings.stamina_regen, 1.0, 0, " /s", func(v: float) -> void: DevSettings.stamina_regen = v)

	# ---- Spawner ----
	var spawner: VBoxContainer = _make_tab(tabs, "Spawner")
	_add_note(spawner, "Enemy chances are relative weights (they are normalized when an enemy is picked).")
	_add_slider(spawner, "Enemy 1 chance", 0.0, 1.0, 0.01, DevSettings.enemy1_chance, 100.0, 0, " %", func(v: float) -> void: DevSettings.enemy1_chance = v)
	_add_slider(spawner, "Enemy 2 chance", 0.0, 1.0, 0.01, DevSettings.enemy2_chance, 100.0, 0, " %", func(v: float) -> void: DevSettings.enemy2_chance = v)
	_add_slider(spawner, "Enemy 3 chance", 0.0, 1.0, 0.01, DevSettings.enemy3_chance, 100.0, 0, " %", func(v: float) -> void: DevSettings.enemy3_chance = v)
	_add_slider(spawner, "Enemies in wave 1", 0.0, 100.0, 1.0, float(DevSettings.first_wave_enemies), 1.0, 0, "", func(v: float) -> void: DevSettings.first_wave_enemies = int(v))
	_add_slider(spawner, "Variants in wave 1", 0.0, 20.0, 1.0, float(DevSettings.first_wave_variants), 1.0, 0, "", func(v: float) -> void: DevSettings.first_wave_variants = int(v))
	_add_slider(spawner, "Growth per wave", 1.0, 3.0, 0.1, DevSettings.wave_growth, 1.0, 1, " x", func(v: float) -> void: DevSettings.wave_growth = v)
	_add_slider(spawner, "Waves until rank-up", 1.0, 10.0, 1.0, float(DevSettings.waves_per_cycle), 1.0, 0, "", func(v: float) -> void: DevSettings.waves_per_cycle = int(v))
	_add_check(spawner, "Counts restart after a rank-up", DevSettings.reset_count_each_cycle, func(on: bool) -> void: DevSettings.reset_count_each_cycle = on)
	_add_slider(spawner, "Wave duration", 10.0, 120.0, 5.0, DevSettings.wave_duration, 1.0, 0, " s", func(v: float) -> void: DevSettings.wave_duration = v)
	_add_slider(spawner, "Spawn spread", 1.0, 60.0, 1.0, DevSettings.spawn_spread_seconds, 1.0, 0, " s", func(v: float) -> void: DevSettings.spawn_spread_seconds = v)
	_add_slider(spawner, "Max living enemies", 10.0, 2000.0, 10.0, float(DevSettings.max_enemies), 1.0, 0, "", func(v: float) -> void: DevSettings.max_enemies = int(v))

	# ---- Rarity ----
	var rarity: VBoxContainer = _make_tab(tabs, "Rarity")
	_add_check(rarity, "Random extra rank (on top of the wave rank)", DevSettings.random_rarity, func(on: bool) -> void: DevSettings.random_rarity = on)
	_add_note(rarity, "Every normal enemy rolls 0 to 4 extra ranks with these weights. Rank = wave rank + extra (max Mythical).")
	var extra_names: Array[String] = ["+0 ranks", "+1 rank", "+2 ranks", "+3 ranks", "+4 ranks"]
	for i in range(extra_names.size()):
		_add_slider(rarity, "Weight: " + extra_names[i], 0.0, 100.0, 1.0, DevSettings.rarity_weights[i], 1.0, 0, "", _on_rarity_weight_changed.bind(i))

	# ---- Drops ----
	var drops: VBoxContainer = _make_tab(tabs, "Drops")
	_add_note(drops, "Multipliers on top of the drop tables. Chance is capped at 100 %.")
	_add_slider(drops, "Coin drop chance", 0.0, 5.0, 0.1, DevSettings.coin_chance_mult, 1.0, 1, " x", func(v: float) -> void: DevSettings.coin_chance_mult = v)
	_add_slider(drops, "Coin drop amount", 0.0, 5.0, 0.1, DevSettings.coin_amount_mult, 1.0, 1, " x", func(v: float) -> void: DevSettings.coin_amount_mult = v)
	_add_slider(drops, "Pickup drop chance (all)", 0.0, 5.0, 0.1, DevSettings.pickup_chance_mult, 1.0, 1, " x", func(v: float) -> void: DevSettings.pickup_chance_mult = v)
	_add_slider(drops, "Pickup drop amount (all)", 0.0, 5.0, 0.1, DevSettings.pickup_amount_mult, 1.0, 1, " x", func(v: float) -> void: DevSettings.pickup_amount_mult = v)
	_add_note(drops, "Chance per pickup type (multiplied with the setting above):")
	for entry in DevSettings.PICKUP_ITEMS:
		var item_id: StringName = entry[0]
		_add_slider(drops, entry[1], 0.0, 10.0, 0.1, float(DevSettings.item_chance_mult.get(item_id, 1.0)), 1.0, 1, " x", _on_item_chance_changed.bind(item_id))

	_build_event_tab(tabs)
	_build_faction_tab(tabs)
	_build_needs_tab(tabs)

	# ---- footer ----
	_add_button(_dev_holder, "Reset all to defaults", _reset_developer)
	_add_button(_dev_holder, "Back", _open_main)


# --------------------------------------------------
# DEVELOPER TABS: EVENTS, FACTIONS, NEEDS
# --------------------------------------------------

func _build_event_tab(tabs: TabContainer) -> void:
	var tab: VBoxContainer = _make_tab(tabs, "Events")
	_add_note(tab, "The wave event (the old wave system) is OFF by default. While it runs, every NPC except unique ones is hostile to the player, the hourglass appears and enemies spawn in waves with the rarity drop tables. When it stops, its NPCs disappear.")
	var wave_event := GameEvent.find(get_tree(), &"wave")
	if wave_event == null:
		_add_note(tab, "No wave event found in the scene.")
		return

	var status := Label.new()
	tab.add_child(status)
	var refresh_status: Callable = func() -> void:
		status.text = "Wave event: %s" % ("RUNNING" if wave_event.is_active else "off")
	refresh_status.call()
	_add_button(tab, "Start / stop the wave event", func() -> void:
		wave_event.toggle()
		refresh_status.call()
	)


func _build_faction_tab(tabs: TabContainer) -> void:
	var tab: VBoxContainer = _make_tab(tabs, "Factions")
	_add_note(tab, "The player's standing with each faction, -100 to 100: friendly from %d, hostile at %d or less. Hitting a peaceful NPC costs 5 points with its faction, killing it 10 more (ActionWeight: hostile / evil)." % [Relation.FRIENDLY_FROM, Relation.HOSTILE_UNTIL])
	for faction in Faction.regular():
		_add_slider(tab, Faction.display_name(faction), -100.0, 100.0, 1.0, float(Relations.faction_points(faction)), 1.0, 0, " pts",
			func(v: float) -> void: Relations.set_faction_points(faction, int(v)))
	_add_button(tab, "Reset all relations", func() -> void:
		Relations.reset()
		_build_developer_content()
		_show_panel(_dev_panel)
	)


func _build_needs_tab(tabs: TabContainer) -> void:
	var tab: VBoxContainer = _make_tab(tabs, "Needs")
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		_add_note(tab, "No player found.")
		return

	_add_note(tab, "Hunger runs down by 20 per minute for the player (NPCs: light 2, medium 3, heavy 4, special 0, doubling per rarity step), thirst by 10. At 0 hunger you lose 5 health per second and move and hit at half strength.")
	_add_slider(tab, "Hunger", 0.0, 100.0, 1.0, player.hunger.value, 1.0, 0, "", func(v: float) -> void: player.hunger.value = v)
	_add_slider(tab, "Thirst (mood: 80+ happy, 50+ unrest, 10+ unhappy)", 0.0, 100.0, 1.0, player.thirst.value, 1.0, 0, "", func(v: float) -> void: player.thirst.value = v)
	_add_button(tab, "Put 3 sandwiches and 3 beers in the inventory", func() -> void:
		player.inventory.add(&"sandwich", 3)
		player.inventory.add(&"beer", 3)
	)

	_add_note(tab, "Values of the need items (ItemEconomy): they can change at any time, the stores and NPCs read them.")
	for item_id in [&"sandwich", &"beer"]:
		var item: ItemData = ItemDatabase.get_item(item_id)
		if item == null:
			continue
		_add_slider(tab, "%s: price" % item.display_name, 0.0, 20.0, 1.0, float(item.base_price if not ItemEconomy.price_overrides.has(item_id) else ItemEconomy.price_overrides[item_id]), 1.0, 0, " coins",
			func(v: float) -> void: ItemEconomy.set_price(item_id, int(v)))
		_add_slider(tab, "%s: restores" % item.display_name, 0.0, 100.0, 1.0, ItemEconomy.restore_of(item), 1.0, 0, "",
			func(v: float) -> void: ItemEconomy.set_restore(item_id, v))
	_add_slider(tab, "All need items: price multiplier", 0.1, 5.0, 0.1, float(ItemEconomy.category_price_multiplier.get(ItemData.Category.NEED, 1.0)), 1.0, 1, " x",
		func(v: float) -> void: ItemEconomy.category_price_multiplier[ItemData.Category.NEED] = v)

	_add_note(tab, "Abilities the player has to unlock (how is not decided yet):")
	for ability in PlayerAbilities.all_ids():
		_add_check(tab, String(PlayerAbilities.NAMES[ability]), player.abilities.has(ability),
			func(on: bool) -> void:
				if on:
					player.abilities.unlock(ability)
				else:
					player.abilities.lock(ability)
		)


# --------------------------------------------------
# SETTINGS
# --------------------------------------------------

func _build_fps_label() -> void:
	_fps_label = Label.new()
	_fps_label.visible = _show_fps
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 4)
	add_child(_fps_label)
	_fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_fps_label.offset_left = 10.0
	_fps_label.offset_top = 8.0


func _read_current_settings() -> void:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	_fullscreen = mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	_vsync = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	_volume = db_to_linear(AudioServer.get_bus_volume_db(0))


# Only a saved file is applied at startup, so the project's own display settings stay untouched
# until the player changes something.
func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return

	_fullscreen = config.get_value("display", "fullscreen", _fullscreen)
	_vsync = config.get_value("display", "vsync", _vsync)
	_show_fps = config.get_value("display", "show_fps", _show_fps)
	_volume = config.get_value("audio", "volume", _volume)
	GameSettings.auto_attack = config.get_value("gameplay", "auto_attack", GameSettings.auto_attack)

	_apply_fullscreen()
	_apply_vsync()
	_apply_volume()


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen", _fullscreen)
	config.set_value("display", "vsync", _vsync)
	config.set_value("display", "show_fps", _show_fps)
	config.set_value("audio", "volume", _volume)
	config.set_value("gameplay", "auto_attack", GameSettings.auto_attack)
	config.save(SETTINGS_PATH)


func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _apply_vsync() -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if _vsync else DisplayServer.VSYNC_DISABLED
	)


func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(_volume, 0.0001)))
