# pickup_area.gd
extends Area3D

@onready var ui = get_tree().get_first_node_in_group("interface")

@onready var weapon_handler = get_parent().get_node("Camera3D/CanvasLayer/SubViewportContainer/SubViewport/ViewModelCamera/WeaponHandler")

var focused_pickup = null
var pickup_cooldown := false

func _unhandled_input(event):
	# Using 'is_action_just_pressed' is usually safer for single interactions
	if event.is_action_pressed("interact") and focused_pickup and not pickup_cooldown:
		_do_pickup()

func _do_pickup():
	pickup_cooldown = true

	# Case 1: Armor
	if focused_pickup.has_method("collect") and "Armor" in focused_pickup.name:
		focused_pickup.collect(get_parent())
	
	# Case 2: Weapons
	elif "weapon_data" in focused_pickup and focused_pickup.weapon_data != null:
		var weapon_name = focused_pickup.weapon_data.name
		
		weapon_handler.equip_new_weapon(focused_pickup.weapon_data)
		ui.display_status("+ " + weapon_name)
		
		# --- OBJECTIVE LOGIC: FIND A WEAPON ---
		if SaveManager.game_data.objectives.has("find_weapon"):
			if not SaveManager.game_data.objectives["find_weapon"].done:
				SaveManager.complete_objective("find_weapon")
		
		focused_pickup.queue_free()
	
	# Case 3: Items (Medkits/Resources/Keys)
	elif "item_data" in focused_pickup and focused_pickup.item_data != null:
		var inventory = get_parent().get_node("Inventory")
		var item_name = focused_pickup.item_data.item_name
		
		if inventory:
			if inventory.add_item(focused_pickup.item_data, focused_pickup.quantity):
				ui.display_status("+ " + item_name)
				
				# --- OBJECTIVE LOGIC: SECURITY KEY ---
				if item_name == "Security Key":
					if SaveManager.game_data.objectives.has("get_key"):
						if not SaveManager.game_data.objectives["get_key"].done:
							SaveManager.complete_objective("get_key")
							
				focused_pickup.queue_free()
	# Case 4: Custom Interactables (Objective items, buttons, radios, etc.)
	elif focused_pickup.has_method("interact"):
		focused_pickup.interact(get_parent()) # Pass the player in case the object needs it

	focused_pickup = null
	ui.set_interaction_prompt("", false, null)

	await get_tree().create_timer(0.5).timeout
	pickup_cooldown = false

func _physics_process(_delta):
	if pickup_cooldown: return

	var all_nodes = get_overlapping_bodies() + get_overlapping_areas()
	var nearest = null
	var nearest_dist = INF

	for node in all_nodes:
		if node.has_method("get_prompt"):
			var d = global_position.distance_to(node.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = node

	if nearest != focused_pickup:
		focused_pickup = nearest
		if focused_pickup:
			var icon = null
			var detail_1 = ""
			var detail_2 = ""
			
			if "weapon_data" in focused_pickup and focused_pickup.weapon_data != null:
				var data = focused_pickup.weapon_data
				icon = data.weapon_icon
				detail_1 = WeaponData.FireMode.keys()[data.fire_mode]
				detail_2 = WeaponData.AmmoType.keys()[data.ammo_type]
			
			elif "item_data" in focused_pickup and focused_pickup.item_data != null:
				var data = focused_pickup.item_data
				icon = data.icon
				detail_1 = Item.ItemType.keys()[data.type]
				if data.item_name.to_lower().contains("key"):
					detail_2 = "USE TO OPEN ROOMS"
				else:
					detail_2 = "RESTORES " + str(data.value) + " HP"
			
			ui.set_interaction_prompt(focused_pickup.get_prompt(), true, icon, detail_1, detail_2)
		else:
			ui.set_interaction_prompt("", false, null)

func _on_body_entered(_body): pass
func _on_body_exited(_body): pass
