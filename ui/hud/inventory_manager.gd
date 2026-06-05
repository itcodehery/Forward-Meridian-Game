# inventory_manager.gd
extends PanelContainer

@onready var current_item_label = $VBoxContainer/CurrentItem
@onready var grid_container = $VBoxContainer/GridContainer
@onready var slots_ui = $VBoxContainer/GridContainer.get_children()

var selected_index: int = 0
var inv_data = null

func _ready():
	hide()
	await get_tree().process_frame
	
	var player = get_tree().get_first_node_in_group("players")
	if player:
		inv_data = player.get_node("Inventory")
		if inv_data:
			if inv_data.inventory_updated.is_connected(update_ui):
				inv_data.inventory_updated.disconnect(update_ui)
			
			inv_data.inventory_updated.connect(update_ui)
			
			# Initial setup
			update_ui(inv_data.slots)
			_update_selection_visuals()

func _input(event):
	if event.is_action_pressed("toggle_inventory"):
		show()
	elif event.is_action_released("toggle_inventory"):
		hide()

	if is_visible_in_tree():
		if event.is_action_pressed("scroll_up"):
			selected_index = (selected_index - 1 + slots_ui.size()) % slots_ui.size()
			_update_selection_visuals()
		
		if event.is_action_pressed("scroll_down"):
			selected_index = (selected_index + 1) % slots_ui.size()
			_update_selection_visuals()

		if event.is_action_pressed("interact"):
			if inv_data:
				inv_data.use_item_at_index(selected_index)

func _update_selection_visuals():
	for i in range(slots_ui.size()):
		var border = slots_ui[i].get_node_or_null("SelectionBorder")
		if i == selected_index:
			if border: border.show()
			slots_ui[i].modulate = Color(1.5, 1.5, 1.5, 1.0)
		else:
			if border: border.hide()
			slots_ui[i].modulate = Color(1.0, 1.0, 1.0, 0.4)
	
	# Update the Top Label with the selected item's name
	_update_header_text()

func _update_header_text():
	if inv_data and selected_index < inv_data.slots.size():
		var current_slot = inv_data.slots[selected_index]
		if current_slot.item != null:
			current_item_label.text = current_slot.item.item_name.to_upper()
		else:
			current_item_label.text = "FWD / INVENTORY"

func update_ui(slots_array: Array):
	for i in range(slots_ui.size()):
		var slot_data = slots_array[i]
		var icon_rect = slots_ui[i].get_node("ItemIcon")
		var amount_label = slots_ui[i].get_node_or_null("AmountLabel")
		
		if slot_data.item != null:
			icon_rect.texture = slot_data.item.icon
			icon_rect.show()
			if amount_label:
				amount_label.text = "x" + str(slot_data.amount)
				amount_label.visible = slot_data.amount > 1
		else:
			icon_rect.texture = null
			icon_rect.hide()
			if amount_label: amount_label.hide()
	
	# Refresh header text in case the item in the current slot was used/changed
	_update_header_text()
