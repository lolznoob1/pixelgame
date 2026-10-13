extends CanvasLayer
class_name UpgradeMenu
## The upgrade and shop window. Press T to open it (the game is paused while it is open); T or ESC closes it.
## The shop is restocked when a new wave starts (see start_wave), the window never opens by itself.
##   - Stats: spend coins on permanent upgrades (see UpgradeCatalog).
##   - Shop: four random offers (weapons and the health pack, see ShopCatalog). Prices double with
##     every enemy rank-up.
## The window is built in code, so there is no scene to maintain.

signal closed

const SHOP_SLOTS: int = 4

## The player. Set by main.gd.
var player: Node

var _player: Node
var _wave: int = 1
var _title: Label
var _coins_label: Label
var _price_note: Label
var _continue_button: Button
var _rows: Dictionary = {}              # upgrade id -> {"level": Label, "button": Button}
var _slot_widgets: Array[Dictionary] = []  # per shop slot: root, icon, name, price, button
var _offers: Array[Dictionary] = []     # the current offers: item, price (already multiplied), sold
var _price_multiplier: int = 1


func _enter_tree() -> void:
	add_to_group("upgrade_menu")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # must keep working while the tree is paused
	layer = 30
	visible = false
	_build()

	# The key is registered in project.godot; this only protects against it being removed there.
	if not InputMap.has_action("open_upgrades"):
		InputMap.add_action("open_upgrades")
		var key_event := InputEventKey.new()
		key_event.physical_keycode = KEY_T
		InputMap.action_add_event("open_upgrades", key_event)


## A new wave started: the shop gets new offers and the prices follow the enemy rank (they double per rank).
## This does NOT open the window.
func start_wave(wave: int, rank: int = 0) -> void:
	_wave = wave
	_price_multiplier = ShopCatalog.price_multiplier(rank)
	_roll_shop()
	if visible:
		_refresh()


## Opens the window and pauses the game.
func open() -> void:
	if not is_instance_valid(player):
		return
	_player = player
	_title.text = "WAVE %d  -  Upgrades & Shop" % _wave
	_refresh()
	visible = true
	get_tree().paused = true
	_continue_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible:
		# T or ESC closes it again.
		if event.is_action_pressed("open_upgrades") or event.is_action_pressed("ui_cancel"):
			_close()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("open_upgrades"):
		# Not while something else has paused the game (pause menu, game over) or the player is dead.
		if get_tree().paused or not is_instance_valid(player) or bool(player.get("is_defeated")):
			return
		open()
		get_viewport().set_input_as_handled()


func _close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()


# --------------------------------------------------
# BUILDING
# --------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # clicks must not reach the game behind
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820.0, 0.0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	box.add_child(_title)

	_coins_label = Label.new()
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coins_label.add_theme_font_size_override("font_size", 20)
	_coins_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	box.add_child(_coins_label)

	box.add_child(HSeparator.new())
	_build_stats(box)
	box.add_child(HSeparator.new())
	_build_shop(box)
	box.add_child(HSeparator.new())

	_continue_button = Button.new()
	_continue_button.text = "Continue"
	_continue_button.custom_minimum_size = Vector2(0.0, 38.0)
	_continue_button.pressed.connect(_close)
	box.add_child(_continue_button)


func _build_stats(box: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "STATS"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	box.add_child(header)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 3)
	box.add_child(grid)

	for def in UpgradeCatalog.UPGRADES:
		var name_label := Label.new()
		name_label.text = def["name"]
		name_label.custom_minimum_size = Vector2(200.0, 0.0)
		grid.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = def["desc"]
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		grid.add_child(desc_label)

		var level_label := Label.new()
		level_label.custom_minimum_size = Vector2(60.0, 0.0)
		grid.add_child(level_label)

		var buy_button := Button.new()
		buy_button.custom_minimum_size = Vector2(120.0, 0.0)
		buy_button.pressed.connect(_on_upgrade_pressed.bind(def["id"]))
		grid.add_child(buy_button)

		_rows[def["id"]] = {"level": level_label, "button": buy_button, "widgets": [name_label, desc_label, level_label, buy_button]}


# The shop: a centered box with four offers.
func _build_shop(box: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "SHOP"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	box.add_child(header)

	var center := CenterContainer.new()
	box.add_child(center)

	var shop_panel := PanelContainer.new()
	center.add_child(shop_panel)

	var shop_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		shop_margin.add_theme_constant_override("margin_" + side, 10)
	shop_panel.add_child(shop_margin)

	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 14)
	shop_margin.add_child(slots)

	for i in range(SHOP_SLOTS):
		var slot := VBoxContainer.new()
		slot.custom_minimum_size = Vector2(150.0, 0.0)
		slot.add_theme_constant_override("separation", 3)
		slots.add_child(slot)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(48.0, 48.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # keep the pixel art sharp
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.add_child(icon)

		var name_label := Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(name_label)

		var price_label := Label.new()
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		slot.add_child(price_label)

		var buy_button := Button.new()
		buy_button.custom_minimum_size = Vector2(0.0, 30.0)
		buy_button.pressed.connect(_on_shop_pressed.bind(i))
		slot.add_child(buy_button)

		_slot_widgets.append({"root": slot, "icon": icon, "name": name_label, "price": price_label, "button": buy_button})

	_price_note = Label.new()
	_price_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price_note.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	box.add_child(_price_note)


# --------------------------------------------------
# SHOP LOGIC
# --------------------------------------------------

# New random offers every time the window opens; prices already include the rank multiplier.
func _roll_shop() -> void:
	_offers = ShopCatalog.roll_offers(SHOP_SLOTS)
	for offer in _offers:
		offer["price"] = int(offer["price"]) * _price_multiplier

	for i in range(SHOP_SLOTS):
		if i >= _offers.size():
			continue
		var item := _offers[i]["item"] as ItemData
		var widgets: Dictionary = _slot_widgets[i]
		(widgets["icon"] as TextureRect).texture = item.texture
		(widgets["name"] as Label).text = item.display_name
		(widgets["price"] as Label).text = "%d coins" % int(_offers[i]["price"])

	_price_note.text = "Shop prices double with every enemy rank-up (now x%d)" % _price_multiplier


func _on_shop_pressed(index: int) -> void:
	if not is_instance_valid(_player) or index >= _offers.size():
		return

	var offer: Dictionary = _offers[index]
	if offer["sold"]:
		return

	var item := offer["item"] as ItemData
	var price: int = offer["price"]
	if _player.get_item_count(&"coin") < price or not _player.can_collect_item(item):
		return

	_player.take_from_inventory(&"coin", price)
	_player.collect_item(item)  # the AK-47 equips / adds bullets, the health pack heals
	offer["sold"] = true
	_refresh()


func _on_upgrade_pressed(id: StringName) -> void:
	if is_instance_valid(_player) and _player.buy_upgrade(id):
		_refresh()


func _refresh() -> void:
	if not is_instance_valid(_player):
		return

	var coins: int = _player.get_item_count(&"coin")
	_coins_label.text = "Coins: %d" % coins

	# stats
	for def in UpgradeCatalog.UPGRADES:
		var id: StringName = def["id"]
		var row: Dictionary = _rows[id]
		# Upgrades that need an ability stay hidden until it is unlocked.
		var requires: StringName = def.get("requires", &"")
		var available: bool = requires == &"" or _player.abilities.has(requires)
		for widget in row["widgets"]:
			(widget as Control).visible = available
		if not available:
			continue
		var level: int = _player.get_upgrade_level(id)
		var max_level: int = def["max"]

		(row["level"] as Label).text = "Lv %d/%d" % [level, max_level]

		var button := row["button"] as Button
		if level >= max_level:
			button.text = "MAX"
			button.disabled = true
		else:
			var cost: int = _player.get_upgrade_cost(id)
			button.text = "Buy  (%d)" % cost
			button.disabled = coins < cost

	# shop
	for i in range(SHOP_SLOTS):
		var widgets: Dictionary = _slot_widgets[i]
		var slot_root := widgets["root"] as Control
		slot_root.visible = i < _offers.size()
		if i >= _offers.size():
			continue

		var offer: Dictionary = _offers[i]
		var button := widgets["button"] as Button
		if offer["sold"]:
			button.text = "Sold"
			button.disabled = true
		elif not _player.can_collect_item(offer["item"]):
			button.text = "Full"  # e.g. full health, or the rifle already holds 300 bullets
			button.disabled = true
		else:
			button.text = "Buy"
			button.disabled = coins < int(offer["price"])
