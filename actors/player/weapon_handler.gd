extends Node3D

enum State { IDLE, EQUIPPING, FIRING, RELOADING }
var current_state: State = State.IDLE

# --- Node References ---
@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("players")
@onready var slots = { "slot_1": $Primary, "slot_2": $Secondary, "melee": $Melee }
@onready var aim_cast = %AimCast_U 

# --- Audio Layers ---
@onready var audio_main = AudioStreamPlayer.new()
@onready var audio_tail = AudioStreamPlayer.new()
@onready var audio_mech = AudioStreamPlayer.new() # Reloads and empty clicks

# --- Signals ---
signal ammo_changed(mag, reserve, is_melee, uses_battery)
signal heat_changed(current_heat, is_overheated)
signal weapon_changed(weapon_name, is_melee, icon)
signal crosshair_updated(crosshair_data: CrosshairData)
signal weapon_fired()
signal camera_recoil_requested(kick_vector: Vector2)
signal camera_trauma_requested(amount: float) 
signal reload_started(duration: float, is_overheat: bool)

# --- Weapon Data ---
@export var slot_1_data: WeaponData
@export var slot_2_data: WeaponData
@export var melee_data: WeaponData
@export var generic_pickup_scene: PackedScene
@export var bullet_hole_scene: PackedScene

# --- Tracking ---
var mags := { "slot_1": 0, "slot_2": 0 }
var ammo_pools := {}
var heat_levels := { "slot_1": 0.0, "slot_2": 0.0 }
var overheat_timers := { "slot_1": 0.0, "slot_2": 0.0 }
var bloom_levels := { "slot_1": 0.0, "slot_2": 0.0 }
var current_slot = "melee"

# --- Spring Physics (Organic Recoil) ---
var recoil_rot: Vector3 = Vector3.ZERO
var recoil_rot_vel: Vector3 = Vector3.ZERO
var recoil_pos: Vector3 = Vector3.ZERO
var recoil_pos_vel: Vector3 = Vector3.ZERO

# --- Sway & Bobbing ---
@export var sway_amount: float = 0.002
var mouse_input: Vector2 = Vector2.ZERO
var bob_time: float = 0.0
var breathe_time: float = 0.0
@export var sprint_pos_offset: Vector3 = Vector3(0.2, -0.35, -0.2)
@export var sprint_rot_offset: Vector3 = Vector3(0.6, 1.4, -0.6) 

# --- Player State ---
var is_ads: bool = false
var is_sprinting: bool = false
var is_crouching: bool = false

# --- Timers ---
var action_timer: float = 0.0 

func _ready():
	add_child(audio_main)
	add_child(audio_tail)
	add_child(audio_mech) 
	
	for type in WeaponData.AmmoType.values():
		ammo_pools[type] = WeaponData.get_default_reserve(type)

	refresh_weapon_visuals()
	call_deferred("switch_to", "melee")

func update_sway_input(relative_input: Vector2):
	mouse_input = relative_input

# ─────────────────────────────────────────────
# LOGIC & FSM
# ─────────────────────────────────────────────
func _physics_process(delta: float):
	_process_heat_and_bloom(delta)
	_process_spring_physics(delta)
	_process_sway_and_bob(delta)
	
	var data = get_current_data()
	if not data: return

	match current_state:
		State.EQUIPPING:
			action_timer -= delta
			if action_timer <= 0.0:
				current_state = State.IDLE
				
		State.RELOADING:
			action_timer -= delta
			if action_timer <= 0.0:
				_finish_reload()
				
		State.FIRING:
			action_timer -= delta
			if action_timer <= 0.0:
				current_state = State.IDLE
				
		State.IDLE:
			_handle_idle_inputs(data)

func _handle_idle_inputs(data: WeaponData):
	if is_sprinting: return
	if current_slot in overheat_timers and overheat_timers[current_slot] > 0.0: return 
	
	if not data.is_melee and not data.uses_battery and get_current_mag() <= 0 and get_current_reserve() > 0:
		begin_reload()
		return

	var wants_to_shoot = false
	if data.fire_mode in [WeaponData.FireMode.AUTO, WeaponData.FireMode.BEAM]:
		wants_to_shoot = Input.is_action_pressed("fire")
	else:
		wants_to_shoot = Input.is_action_just_pressed("fire")

	if wants_to_shoot:
		if get_current_mag() <= 0 and not data.is_melee:
			_play_empty_click(data)
		else:
			shoot()

# ─────────────────────────────────────────────
# FIRING MECHANICS
# ─────────────────────────────────────────────
func shoot():
	var data = get_current_data()
	current_state = State.FIRING
	action_timer = data.fire_rate
	
	_consume_ammo_and_heat(data)
	_do_effects(data)

	if data.fire_mode == WeaponData.FireMode.PROJECTILE:
		_fire_projectile(data)
	else:
		_do_hitscan(data)
		
	if data.damage > 40.0:
		camera_trauma_requested.emit(0.3)

func _consume_ammo_and_heat(data: WeaponData):
	if not data.is_melee:
		set_current_mag(get_current_mag() - 1)
		update_ui_ammo()
		
	if data.can_overheat and current_slot in heat_levels:
		heat_levels[current_slot] += data.heat_per_shot
		if heat_levels[current_slot] >= 1.0:
			heat_levels[current_slot] = 1.0
			overheat_timers[current_slot] = data.overheat_penalty_time
			heat_changed.emit(1.0, true) 
			reload_started.emit(data.overheat_penalty_time, true)
			if data.reload_sound:
				audio_mech.stream = data.reload_sound
				audio_mech.play()
		else:
			heat_changed.emit(heat_levels[current_slot], false)

func _do_hitscan(data: WeaponData):
	var space_state = get_world_3d().direct_space_state
	var pellets = data.pellet_count if "pellet_count" in data else 1
	var active_spread = data.base_spread
	
	if current_slot in bloom_levels: active_spread += bloom_levels[current_slot]
	if is_ads: active_spread = data.ads_spread
	if is_sprinting: active_spread *= data.sprint_multiplier
	elif is_crouching: active_spread *= data.crouch_multiplier

	for i in range(pellets):
		var spread_x = randf_range(-active_spread, active_spread)
		var spread_y = randf_range(-active_spread, active_spread)
		var aim_dir = (-aim_cast.global_transform.basis.z + (aim_cast.global_transform.basis.x * spread_x) + (aim_cast.global_transform.basis.y * spread_y)).normalized()
		
		var current_pos = aim_cast.global_position
		var penetrations = 0
		var max_pen = data.max_penetrations if "max_penetrations" in data else 1
		
		while penetrations < max_pen:
			var end_pos = current_pos + (aim_dir * data.max_range)
			var query = PhysicsRayQueryParameters3D.create(current_pos, end_pos)
			query.collision_mask = aim_cast.collision_mask
			query.collide_with_areas = aim_cast.collide_with_areas
			query.collide_with_bodies = aim_cast.collide_with_bodies
			if is_instance_valid(player):
				query.exclude = [player.get_rid()]
			var result = space_state.intersect_ray(query)
			
			if result:
				var target = result.collider
				var hit_pos = result.position
				var hit_normal = result.normal
				var distance = global_position.distance_to(hit_pos)
				
				if target.has_method("take_damage"):
					var dmg = data.damage
					if distance > data.effective_range:
						dmg = max(1.0, data.damage - ((distance - data.effective_range) * data.falloff_multiplier))
					dmg = dmg / (penetrations + 1) 
					target.take_damage(dmg)

				if bullet_hole_scene and not data.is_melee:
					var hole = bullet_hole_scene.instantiate()
					get_tree().root.add_child(hole)
					hole.global_position = hit_pos
					if hit_normal.is_equal_approx(Vector3.UP) or hit_normal.is_equal_approx(Vector3.DOWN):
						hole.look_at(hit_pos + hit_normal, Vector3.RIGHT)
					else:
						hole.look_at(hit_pos + hit_normal, Vector3.UP)
				
				current_pos = hit_pos + (aim_dir * 0.15)
				penetrations += 1
			else:
				break 

func _fire_projectile(data: WeaponData):
	if data.projectile_scene:
		var proj = data.projectile_scene.instantiate()
		get_tree().root.add_child(proj)
		proj.global_transform = aim_cast.global_transform
		proj.global_position -= proj.global_transform.basis.z * 1.0
		if proj is RigidBody3D:
			proj.linear_velocity = -proj.global_transform.basis.z * data.projectile_speed

# ─────────────────────────────────────────────
# EFFECTS, AUDIO, AND RECOIL
# ─────────────────────────────────────────────
func _do_effects(data: WeaponData):
	if data.fire_sound:
		audio_main.stream = data.fire_sound
		audio_main.pitch_scale = randf_range(0.92, 1.08)
		audio_main.play()
	if data.fire_tail_sound:
		audio_tail.stream = data.fire_tail_sound
		audio_tail.play()

	if data.muzzle_flash_scene:
		var flash = data.muzzle_flash_scene.instantiate()
		slots[current_slot].add_child(flash) 
		flash.global_position = aim_cast.global_position
		get_tree().create_timer(0.05).timeout.connect(flash.queue_free)

	if current_slot in bloom_levels:
		bloom_levels[current_slot] = min(data.max_bloom, bloom_levels[current_slot] + data.bloom_per_shot)
		
	weapon_fired.emit()

	var rx = randf_range(data.kick_impulse.x * 0.8, data.kick_impulse.x * 1.2)
	var ry = randf_range(-data.kick_impulse.y, data.kick_impulse.y)
	var rz = randf_range(-data.kick_impulse.z, data.kick_impulse.z)
	recoil_rot_vel += Vector3(rx, ry, rz) * 100.0 
	
	var px = randf_range(-data.positional_kick.x, data.positional_kick.x)
	var py = randf_range(-data.positional_kick.y, data.positional_kick.y)
	var pz = data.positional_kick.z 
	recoil_pos_vel += Vector3(px, py, pz) * 50.0
	
	camera_recoil_requested.emit(Vector2(rx, ry))

func _play_empty_click(data: WeaponData):
	if not audio_mech.playing and data.empty_click_sound:
		audio_mech.stream = data.empty_click_sound
		audio_mech.play()

# ─────────────────────────────────────────────
# PROCEDURAL ANIMATION (SPRING PHYSICS)
# ─────────────────────────────────────────────
func _process_spring_physics(delta: float):
	var data = get_current_data()
	var stiffness = data.spring_stiffness if data else 100.0
	var damping = data.spring_damping if data else 10.0
	
	var force_rot = (-stiffness * recoil_rot) - (damping * recoil_rot_vel)
	recoil_rot_vel += force_rot * delta
	recoil_rot += recoil_rot_vel * delta
	
	var force_pos = (-stiffness * recoil_pos) - (damping * recoil_pos_vel)
	recoil_pos_vel += force_pos * delta
	recoil_pos += recoil_pos_vel * delta

func _process_sway_and_bob(delta: float):
	breathe_time += delta * 1.5
	var target_pos = Vector3.ZERO
	var target_rot = Vector3.ZERO
	var current_sway = sway_amount
	var data = get_current_data()
	var speed = 10.0

	var is_equipping = (current_state == State.EQUIPPING)
	var equip_offset = (action_timer / 0.5) if is_equipping else 0.0

	if is_sprinting:
		bob_time += delta * 12.0
		target_pos = sprint_pos_offset
		target_rot = sprint_rot_offset
		target_pos.x += sin(bob_time) * 0.04
		target_pos.y += abs(cos(bob_time)) * 0.02
		target_rot.z += sin(bob_time * 0.5) * 0.1
		speed = 8.0
	elif is_ads and data:
		target_pos = data.ads_position
		target_rot = data.ads_rotation
		current_sway *= 0.1 
		speed = data.ads_speed
	else:
		bob_time += delta * 6.0
		target_pos.y += sin(breathe_time) * 0.005 
		if player and player.velocity.length() > 1.0:
			target_pos.x += sin(bob_time) * 0.015 
			target_pos.y += abs(cos(bob_time)) * 0.01

	var mouse_sway_x = -mouse_input.y * current_sway
	var mouse_sway_y = -mouse_input.x * current_sway

	target_pos += Vector3(0, -0.6, 0) * equip_offset
	target_rot += Vector3(1.2, 0, 0) * equip_offset

	position = lerp(position, target_pos + recoil_pos, speed * delta)
	rotation.x = lerp(rotation.x, target_rot.x + mouse_sway_x + recoil_rot.x, speed * delta)
	rotation.y = lerp(rotation.y, target_rot.y + mouse_sway_y + recoil_rot.y, speed * delta)
	rotation.z = lerp(rotation.z, target_rot.z + recoil_rot.z, speed * delta)
	
	mouse_input = Vector2.ZERO

# ─────────────────────────────────────────────
# WEAPON SWITCHING & RELOADING
# ─────────────────────────────────────────────
func switch_to(slot_name):
	if current_state == State.EQUIPPING or slot_name == current_slot: return 

	var target_data = slot_1_data if slot_name == "slot_1" else (slot_2_data if slot_name == "slot_2" else melee_data)
	if target_data == null and slot_name != "melee": return 

	current_slot = slot_name
	current_state = State.EQUIPPING
	action_timer = 0.5 
	
	audio_mech.stop()
	
	for s in slots.keys():
		slots[s].visible = (s == slot_name)
	
	if target_data:
		weapon_changed.emit(target_data.name, target_data.is_melee, target_data.weapon_icon)        
		if target_data.crosshair: crosshair_updated.emit(target_data.crosshair)
		update_ui_ammo()
	else:
		weapon_changed.emit("NO WEAPON", false, null)
		ammo_changed.emit(0, 0, false, false)

func begin_reload():
	var data = get_current_data()
	if not data or data.is_melee or data.uses_battery: return
	
	var needed = data.mag_size - get_current_mag()
	if needed <= 0 or get_current_reserve() <= 0: return
	
	current_state = State.RELOADING
	action_timer = data.reload_time
	reload_started.emit(data.reload_time, false)
	
	if data.reload_sound:
		audio_mech.stream = data.reload_sound
		audio_mech.pitch_scale = randf_range(0.95, 1.05) 
		audio_mech.play()

func _finish_reload():
	var data = get_current_data()
	var needed = data.mag_size - get_current_mag()
	var amount = min(needed, get_current_reserve())
	set_current_mag(get_current_mag() + amount)
	set_current_reserve(get_current_reserve() - amount)
	update_ui_ammo()
	current_state = State.IDLE

# ─────────────────────────────────────────────
# EQUIP AND PICKUP LOGIC
# ─────────────────────────────────────────────
func equip_new_weapon(new_data: WeaponData, starting_mag: int = -1):
	if current_state == State.EQUIPPING: 
		current_state = State.IDLE
		action_timer = 0.0 
		
	if starting_mag == -1: 
		starting_mag = new_data.mag_size
		
	if new_data.is_melee:
		melee_data = new_data
		refresh_weapon_visuals()
		current_slot = "" 
		switch_to("melee")
		return
		
	var target_slot = ""
	if slot_1_data == null:
		target_slot = "slot_1"
	elif slot_2_data == null:
		target_slot = "slot_2"
	else:
		target_slot = current_slot
		if target_slot == "melee": target_slot = "slot_1"
		
	if target_slot == "slot_1": slot_1_data = new_data
	else: slot_2_data = new_data
	
	mags[target_slot] = starting_mag
	heat_levels[target_slot] = 0.0 
	bloom_levels[target_slot] = 0.0
	overheat_timers[target_slot] = 0.0
	
	refresh_weapon_visuals()
	current_slot = "" 
	switch_to(target_slot)

func has_weapon(target_data: WeaponData) -> bool:
	if slot_1_data == target_data: return true
	if slot_2_data == target_data: return true
	if melee_data == target_data: return true
	return false

func interact_pickup(pickup_data: WeaponData, mag_ammo: int, reserve_ammo: int) -> Dictionary:
	if has_weapon(pickup_data):
		if pickup_data.uses_battery:
			return {} 
		var current_res = ammo_pools.get(pickup_data.ammo_type, 0)
		ammo_pools[pickup_data.ammo_type] = current_res + mag_ammo + reserve_ammo
		update_ui_ammo()
		return {} 
		
	var dropped_info = {}
	if slot_1_data != null and slot_2_data != null:
		var target_slot = current_slot
		if target_slot == "melee": target_slot = "slot_1"
		var old_data = slot_1_data if target_slot == "slot_1" else slot_2_data
		
		dropped_info = {
			"weapon_data": old_data,
			"current_mag": mags[target_slot],
			"current_reserve": 0 
		}

	equip_new_weapon(pickup_data, mag_ammo)
	
	if not pickup_data.uses_battery:
		var current_res = ammo_pools.get(pickup_data.ammo_type, 0)
		ammo_pools[pickup_data.ammo_type] = current_res + reserve_ammo
		
	return dropped_info

# ─────────────────────────────────────────────
# UTILITY FUNCTIONS
# ─────────────────────────────────────────────
func _process_heat_and_bloom(delta: float):
	for slot in ["slot_1", "slot_2"]:
		var data = slot_1_data if slot == "slot_1" else slot_2_data
		if not data: continue
		
		if bloom_levels[slot] > 0.0:
			bloom_levels[slot] = max(0.0, bloom_levels[slot] - (data.bloom_recovery_speed * delta))
			
		if overheat_timers[slot] > 0.0:
			overheat_timers[slot] -= delta
			if overheat_timers[slot] <= 0.0:
				heat_levels[slot] = 0.0 
				if slot == current_slot: heat_changed.emit(0.0, false)
		elif data.can_overheat and heat_levels[slot] > 0.0:
			heat_levels[slot] = max(0.0, heat_levels[slot] - (data.cooling_rate * delta))
			if slot == current_slot: heat_changed.emit(heat_levels[slot], false)

func set_ads(active: bool): is_ads = active
func set_crouching(active: bool): is_crouching = active
func set_sprinting(active: bool): is_sprinting = active
func get_current_mag() -> int: return mags.get(current_slot, 0)
func set_current_mag(val: int) -> void: if current_slot in mags: mags[current_slot] = val
func get_current_reserve() -> int:
	var data = get_current_data()
	return ammo_pools.get(data.ammo_type, 0) if data and not data.is_melee else 0
func set_current_reserve(val: int) -> void:
	var data = get_current_data()
	if data and not data.uses_battery: ammo_pools[data.ammo_type] = val
func get_current_data() -> WeaponData:
	return slot_1_data if current_slot == "slot_1" else (slot_2_data if current_slot == "slot_2" else melee_data)

func update_ui_ammo():
	var data = get_current_data()
	if data: ammo_changed.emit(get_current_mag(), get_current_reserve(), data.is_melee, data.uses_battery)

func refresh_weapon_visuals():
	_update_slot_visual("slot_1", slot_1_data)
	_update_slot_visual("slot_2", slot_2_data)
	_update_slot_visual("melee", melee_data)

func _update_slot_visual(slot_id: String, data: WeaponData):
	var slot_node = slots[slot_id]
	for child in slot_node.get_children():
		slot_node.remove_child(child) 
		child.queue_free()
	if data and data.weapon_mesh:
		var instance = data.weapon_mesh.instantiate()
		slot_node.add_child(instance)
		if instance: _set_layer_recursive(instance, 2)

func _set_layer_recursive(node: Node, layer: int):
	if node is VisualInstance3D:
		node.layers = 0 
		node.set_layer_mask_value(layer, true) 
		if node is MeshInstance3D:
			var outline_mat = preload("res://weapons/comic_outline_mat.tres")
			for i in range(node.mesh.get_surface_count()):
				var active_mat = node.get_active_material(i)
				if active_mat: active_mat.next_pass = outline_mat
	for child in node.get_children():
		_set_layer_recursive(child, layer)
