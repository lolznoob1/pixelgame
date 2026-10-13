extends CanvasLayer
class_name StoreWindow
## The shop window of a store (StoreEntrance). Opens with E at the entrance; the game is paused while it is open.
## Shows what the store sells with the CURRENT price (ItemEconomy) and what the item restores. Bought items go
## into the player's inventory (G eats, B drinks).

var _store: StoreEntrance
var _player: Node
var _title: Label
var _coins: Label
var _list: VBoxContainer
var _message: Label


## Opens the window of a store for the player (creates the window the first time).
static func open_for(store: StoreEntrance, player: Node) -> void:
	var tree: SceneTree = store.get_tree()
	var window := tree.get_first_node_in_group("store_window") as StoreWindow
	if window == null:
		window = StoreWindow.new()
		window.name = "StoreWindow"
		tree.current_scene.add_child(window)
	window.open(store, player)


func _enter_tree() -> void:
	add_to_group("store_window")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # works while the tree is paused
	layer = 31
	visible = false
	_build()


func open(store: StoreEntrance, player: Node) -> void:
	_store = store
	_player = player
	_title.text = store.store_name
	_message.text = ""
	_refresh()
	visible = true
	get_tree().paused = true


func _close() -> void:
	visible = false
	get_tree().paused = false
	if is_instance_valid(_player):
		_player.set("interact_cooldown", 0.3)  # the E that closed it must not open it again


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact")):
		_close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520.0, 0.0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	box.add_child(_title)

	_coins = Label.new()
	_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coins.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	box.add_child(_coins)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	box.add_child(_list)

	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	box.add_child(_message)

	var note := Label.new()
	note.text = "Food and drinks go into your inventory.  G: eat    B: drink    E / Esc: leave"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	box.add_child(note)

	var close := Button.new()
	close.text = "Leave"
	close.custom_minimum_size = Vector2(0.0, 36.0)
	close.pressed.connect(_close)
	box.add_child(close)


# Rebuilt on every change: the prices can change while the game runs (ItemEconomy).
func _refresh() -> void:
	if not is_instance_valid(_player) or _store == null:
		return

	var coins: int = int(_player.call("get_item_count", &"coin"))
	_coins.text = "Coins: %d" % coins

	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	for item in _store.items_for_sale():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_list.add_child(row)

		var icon := TextureRect.new()
		icon.texture = item.texture
		icon.custom_minimum_size = Vector2(40.0, 40.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)

		var name_label := Label.new()
		var restores: String = "hunger" if item.effect == ItemData.Effect.FOOD else "thirst"
		name_label.text = "%s   (+%d %s)" % [item.display_name, roundi(ItemEconomy.restore_of(item)), restores]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var price: int = ItemEconomy.price_of(item)
		var owned := Label.new()
		owned.text = "have %d" % int(_player.call("get_item_count", item.id))
		owned.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
		row.add_child(owned)

		var buy := Button.new()
		buy.text = "Buy  (%d)" % price
		buy.custom_minimum_size = Vector2(110.0, 0.0)
		buy.disabled = coins < price or not _store.has_stock(item.id)
		buy.pressed.connect(_on_buy_pressed.bind(item))
		row.add_child(buy)


func _on_buy_pressed(item: ItemData) -> void:
	var price: int = ItemEconomy.price_of(item)
	if int(_player.call("get_item_count", &"coin")) < price or not _store.has_stock(item.id):
		return
	_player.call("take_from_inventory", &"coin", price)
	_player.get("inventory").add(item.id, 1)
	_store.sold(item, price)
	_message.text = "Bought %s for %d" % [item.display_name, price]
	_refresh()
