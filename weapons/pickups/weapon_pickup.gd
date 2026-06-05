extends Area3D

@export var weapon_data: WeaponData:
	set(value):
		weapon_data = value
		if is_node_ready():
			_update_visuals()

@export var current_mag: int = -1
@export var current_reserve: int = 0

# Player Interaction Variables (Read by player Raycast)
var prompt_text: String = ""
var hold_time: float = 0.0

@onready var visual_parent = $VisualParent

# Animation Settings
var t_bob: float = 0.0

@export_group("Animation")
@export var rotation_speed: float = 2.0
@export var bob_height: float = 0.1
@export var bob_speed: float = 3.0

func _ready():
	# Collision Layer 1 for interaction
	collision_layer = 1
	collision_mask = 0 
	
	# ENHANCEMENT: Desynchronize animation
	# This prevents multiple pickups from bobbing and spinning in perfectly identical unison.
	t_bob = randf() * PI * 2.0
	if visual_parent:
		visual_parent.rotation.y = randf() * PI * 2.0
		
	_update_visuals()

func _process(delta: float):
	if not visual_parent or not weapon_data: return
	
	# 1. Constant Spin
	visual_parent.rotate_y(rotation_speed * delta)
	
	# 2. Smooth Sine Bobbing
	t_bob += delta * bob_speed
	visual_parent.position.y = sin(t_bob) * bob_height

func _update_visuals():
	if not weapon_data: 
		return
	
	prompt_text = "PICK UP " + weapon_data.name.to_upper()
	
	if current_mag == -1:
		current_mag = weapon_data.mag_size
		
	for child in visual_parent.get_children():
		child.queue_free()
	
	if weapon_data.weapon_mesh:
		var model = weapon_data.weapon_mesh.instantiate()
		visual_parent.add_child(model)
		
		model.position = Vector3.ZERO 
		
		# THE FIX: Read the scale directly from the custom resource
		if "pickup_scale" in weapon_data:
			model.scale = weapon_data.pickup_scale
		else:
			model.scale = Vector3(0.2, 0.2, 0.2) # Safe fallback just in case
		
		_disable_physics_recursive(model)

func _disable_physics_recursive(node: Node):
	if node is RigidBody3D:
		node.freeze = true
		node.process_mode = Node.PROCESS_MODE_DISABLED # Updated to explicit Node enum
	for child in node.get_children():
		_disable_physics_recursive(child)

func interact(player):
	if not weapon_data: return
	
	var wh = player.weapon_handler
	if wh:
		# Check for energy weapon duplicates
		if wh.has_weapon(weapon_data) and weapon_data.uses_battery:
			var ui = get_tree().get_first_node_in_group("interface")
			if ui: ui.display_status("ALREADY EQUIPPED")
			return
		
		# Standard pickup/ammo-fill logic
		# Expecting a Dictionary return from the player's weapon handler
		var dropped_info = wh.interact_pickup(weapon_data, current_mag, current_reserve)
		
		# ENHANCEMENT: Safe type checking before spawning the drop
		if typeof(dropped_info) == TYPE_DICTIONARY and not dropped_info.is_empty():
			_spawn_dropped_weapon_in_world(dropped_info, player)
			
		var ui = get_tree().get_first_node_in_group("interface")
		if ui:
			ui.display_status("+" + weapon_data.name.to_upper())
			ui.set_interaction_prompt("", false)
			
		SaveManager.complete_objective("find_weapon")
		queue_free()

func _spawn_dropped_weapon_in_world(dropped_info: Dictionary, player: Node3D):
	var pickup_scene = load(self.scene_file_path) 
	var new_pickup = pickup_scene.instantiate()
	
	get_tree().current_scene.add_child(new_pickup)
	
	var forward_dir = -player.global_transform.basis.z.normalized()
	var drop_pos = player.global_position + (forward_dir * 1.2)
	drop_pos.y += 0.5 
	
	new_pickup.global_position = drop_pos
	
	# Inject the dropped weapon's data
	new_pickup.weapon_data = dropped_info["weapon_data"]
	new_pickup.current_mag = dropped_info["current_mag"]
	new_pickup.current_reserve = dropped_info["current_reserve"]
	
	# WE DELETED THE 'new_pickup.model_scale' LINE HERE.
	# The pickup will now automatically size itself correctly based on its weapon_data!
