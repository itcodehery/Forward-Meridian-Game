# inventory.gd
extends Node

class Slot:
	var item: Item = null
	var amount: int = 0

var slots: Array[Slot] = []
var max_slots: int = 8

signal inventory_updated(slots_array)

func _ready():
	for i in range(max_slots):
		slots.append(Slot.new())
	inventory_updated.emit(slots)

func add_item(new_item: Item, amount_to_add: int = 1) -> bool:
	# 1. Stack logic
	if new_item.max_stack > 1:
		for slot in slots:
			if slot.item == new_item and slot.amount < new_item.max_stack:
				slot.amount += amount_to_add
				print("Item added to slot!")
				inventory_updated.emit(slots)
				return true

	# 2. Empty slot logic
	for slot in slots:
		if slot.item == null:
			slot.item = new_item
			slot.amount = amount_to_add
			print("Item added to slot!")
			inventory_updated.emit(slots)
			return true
	return false

func use_item_at_index(index: int):
	var active_slot = slots[index]
	if active_slot.item == null: return
	
	var item_name = active_slot.item.item_name
	var ui = get_tree().get_first_node_in_group("interface")

	if active_slot.item.is_consumable:
		if active_slot.item.type == Item.ItemType.HEALTH:
			if get_parent().health == 100:
				ui.display_status("HEALTH FULL")
				return
			get_parent().heal(active_slot.item.value)
			# Show the Status: "Used - Common Medkit | +40H"
			ui.display_status("USED - " + item_name + " | +" + str(active_slot.item.value) + "H")
		
		active_slot.amount -= 1
		if active_slot.amount <= 0:
			active_slot.item = null
	
	# Logic for Keys or non-consumables
	else:
		# If you have logic that removes a key after opening a door:
		pass

	inventory_updated.emit(slots)

# Checks if an item with a specific name exists in any slot
func has_item_id(target_name: String) -> bool:
	for slot in slots:
		if slot.item != null and slot.item.item_id == target_name:
			return true
	return false

func remove_item_id(target_name: String):
	var ui = get_tree().get_first_node_in_group("interface")
	for slot in slots:
		if slot.item != null and slot.item.item_id == target_name:
			slot.amount -= 1
			if slot.amount <= 0:
				slot.item = null
			ui.display_status("REMOVED - " + target_name)
			inventory_updated.emit(slots)
			return # Exit after removing one
