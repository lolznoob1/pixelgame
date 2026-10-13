extends CanvasLayer
class_name StorageWindow
## Moves items between the player's inventory and the shared inventory of a faction (FactionStorage).
## The game is paused while it is open.

var _storage: FactionStorage
var _player: Node
var _title: Label
var _list: VBoxContainer


static func open_for(storage: FactionStorage, player: Node) -> void:
	var tree: SceneTree = storage.get_tree()
	var window := tree.get_first_node_in_group("storage_window") as StorageWindow
	if window == null:
		window = StorageWindow.new()
		window.name = "StorageWindow"
		tree.current_scene.add_child(window)
	window.open(storage, player)


func _enter_tree() -> void:
	add_to_group("storage_window")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 31
	visible = false
	_build()


func open(storage: FactionStorage, player: Node) -> void:
	_storage = storage
	_player = player
	_title.text = "%s  (%s)" % [storage.storage_name, Faction.display_name(storage.faction)]
	_refresh()
	visible = true
	get_tree().paused = true


func _close() -> void:
	visible = false
	get_tree().paused = false
	if is_instance_valid(_player):
		_player.set("interact_cooldown", 0.3)


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

	var header := Label.new()
	header.text = "Shared by everybody in this faction.   Storage  |  You"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	box.add_child(header)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	box.add_child(_list)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0.0, 36.0)
	close.pressed.connect(_close)
	box.add_child(close)


func _refresh() -> void:
	if not is_instance_valid(_player) or _storage == null:
		return

	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	var stored: Inventory = _storage.inventory()
	var carried: Inventory = _player.get("inventory")

	# Every item that is in one of the two inventories.
	var ids: Dictionary = {}
	for item_id in stored.ids():
		ids[item_id] = true
	for item_id in carried.ids():
		ids[item_id] = true

	if ids.is_empty():
		var empty := Label.new()
		empty.text = "Nothing here yet."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(empty)
		return

	for item_id in ids:
		var item: ItemData = ItemDatabase.get_item(item_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_list.add_child(row)

		var name_label := Label.new()
		name_label.text = item.display_name if item != null else String(item_id)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var counts := Label.new()
		counts.text = "%d  |  %d" % [stored.count(item_id), carried.count(item_id)]
		counts.custom_minimum_size = Vector2(90.0, 0.0)
		row.add_child(counts)

		var take := Button.new()
		take.text = "Take"
		take.disabled = not stored.has(item_id)
		take.pressed.connect(_transfer.bind(item_id, true))
		row.add_child(take)

		var put := Button.new()
		put.text = "Put"
		put.disabled = not carried.has(item_id)
		put.pressed.connect(_transfer.bind(item_id, false))
		row.add_child(put)


func _transfer(item_id: StringName, take: bool) -> void:
	var stored: Inventory = _storage.inventory()
	var carried: Inventory = _player.get("inventory")
	if take:
		stored.transfer_to(carried, item_id, 1)
	else:
		carried.transfer_to(stored, item_id, 1)
	_refresh()
