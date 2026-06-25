extends CanvasLayer

@onready var stamina_bar = %TextureProgressBar
@onready var stamina_container = %StaminaBar

# --- Ammo UI ---
@onready var ammo_label = %CurrentAmmoLabel
@onready var reserve_label = %CurrentReserveLabel
@onready var weapon_name_label = %GunLabel
@onready var weapon_icon = %WeaponIcon
@onready var reload_bar = %ReloadBar

# --- Interaction UI ---
@onready var interaction_label = %InteractLabel
@onready var sub_details_label = %SubDetailsLabel
@onready var prompt_weapon_icon = %PromptWeaponIcon
@onready var interaction_prompt = %InteractVBox

# --- Vitals UI ---
@onready var health_bar = %HealthBar
@onready var armor_bar_catchup = %ArmorBarCatchup
@onready var armor_bar = %ArmorBar

# --- Equipment UI ---
@onready var grapple_icon = %GrappleBar
@onready var double_jump_icon = %DoubleJumpBar
@onready var grenade_bar = %GrenadeBar
@onready var grenade_count_label = %GrenadeCount
# --- Objective UI ---
@onready var objective_label = %ObjectiveLabel

# --- Status Indicator ---
@onready var status_box = %StatusBox
@onready var status_text = %StatusText
@onready var hazard_container = %HazardContainer
var hazard_tween;

# --- Vignette & Waypoints ---
@onready var health_vignette = %HealthVignette
@onready var waypoint_icon = %WaypointIcon
@onready var waypoint_distance_label = %WaypointDistanceLabel
var vignette_tween: Tween
var _waypoint_update_timer: float = 0.0
var _cached_target_wp: Node3D = null

# --- Debug UI ---
@onready var fps_label = %FPSLabel

var fade_tween: Tween
var show_status_duration : float = 4.0

# --- Stamina Bar Variables ---
var target_stamina : float = 100.0
var fade_timer : Timer

func _ready():
	add_to_group("interface")
	var viewport = $SubViewportContainer/SubViewport
	viewport.size = get_viewport().size
	
	fade_timer = Timer.new()
	add_child(fade_timer)
	fade_timer.wait_time = 3.0
	fade_timer.one_shot = true
	fade_timer.timeout.connect(_fade_out_stamina)
	
	interaction_prompt.visible = false
	weapon_name_label.add_theme_constant_override("char_spacing", 8)
	
	SaveManager.objective_updated.connect(_on_objective_updated)
	
	# Start invisible
	status_text.modulate.a = 0.0
	if health_vignette: health_vignette.material.set_shader_parameter("intensity", 0.0)
	if hazard_container: hazard_container.hide()
	add_to_group("interface")
	
	_setup_scanner_ui()
	
	call_deferred("initialize_ui")

func show_hazard_warning(text: String):
	if not hazard_container: return
	if hazard_container.visible: return
	%HazardLabel.text = text
	hazard_container.show()
	
	if hazard_tween and hazard_tween.is_valid():
		hazard_tween.kill()
		
	hazard_tween = create_tween().set_loops()
	hazard_tween.tween_property(hazard_container, "modulate:a", 0.2, 0.5)
	hazard_tween.tween_property(hazard_container, "modulate:a", 1.0, 0.5)

func hide_hazard_warning():
	if not hazard_container: return
	if hazard_tween and hazard_tween.is_valid():
		hazard_tween.kill()
	hazard_container.hide()
	hazard_container.modulate.a = 1.0

var scanner_panel: Control

func _setup_scanner_ui():
	var scanner_scene = load("res://ui/hud/scanner_ui.tscn")
	if scanner_scene:
		scanner_panel = scanner_scene.instantiate()
		scanner_panel.modulate.a = 0.0
		%HUD.add_child(scanner_panel)
		scanner_panel.hide()

var scanner_tween: Tween

func set_scanner_hud_visible(is_visible: bool):
	var ammo_counter = get_node_or_null("%AmmoCounter")
	if ammo_counter: ammo_counter.visible = is_visible
	
	var hud = get_node_or_null("%HUD")
	if hud:
		var equipment_row = hud.get_node_or_null("EquipmentRow")
		if equipment_row: equipment_row.visible = is_visible
		
		var inventory = hud.get_node_or_null("Inventory")
		if inventory: 
			if is_visible:
				inventory.visible = Input.is_action_pressed("toggle_inventory")
			else:
				inventory.visible = false

func show_scanner(is_scanning: bool, scanner_data: Dictionary = {}):
	if not scanner_panel: return
	
	if scanner_tween and scanner_tween.is_valid():
		scanner_tween.kill()
	
	if is_scanning:
		if not scanner_panel.visible:
			scanner_panel.modulate.a = 0.0
		scanner_panel.show()
		set_scanner_hud_visible(false)
		
		if scanner_panel.has_method("set_lore"):
			scanner_panel.set_lore(scanner_data)
			
		scanner_tween = create_tween()
		scanner_tween.tween_property(scanner_panel, "modulate:a", 1.0, 0.05).set_trans(Tween.TRANS_SINE)
	else:
		set_scanner_hud_visible(true)
		scanner_tween = create_tween()
		scanner_tween.tween_property(scanner_panel, "modulate:a", 0.0, 0.05).set_trans(Tween.TRANS_SINE)
		scanner_tween.tween_callback(scanner_panel.hide)

#func _notification(what):
	##if what == NOTIFICATION_WM_SIZE_CHANGED:
		##var viewport = $SubViewportContainer/SubViewport
		##viewport.size = get_viewport().size

# --- CUTSCENE METHODS ---
func hide_ui():
	# Make the HUD completely transparent instantly
	%HUD.modulate.a = 0.0

func fade_in_ui(duration: float = 1.5):
	# Tween the HUD back to full opacity
	var tween = create_tween()
	tween.tween_property(%HUD, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE)

func initialize_ui():
	var player = get_tree().get_first_node_in_group("players")
	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_health_changed)
			_on_health_changed(player.health)
		
		if player.has_signal("armor_changed"):
			player.armor_changed.connect(_on_armor_changed)
			if "armor" in player: _on_armor_changed(player.armor)
			
		if player.has_signal("stamina_changed"):
			player.stamina_changed.connect(_on_stamina_changed)

		var wh = player.find_child("WeaponHandler", true, false)
		if wh:
			wh.ammo_changed.connect(_on_ammo_changed)
			wh.weapon_changed.connect(_on_weapon_changed)
			wh.reload_started.connect(_on_reload_started)
			wh.heat_changed.connect(_on_heat_changed)
			
			var data = wh.get_current_data()
			if data:
				# FIXED: Updated to pass 3 arguments for weapon and 4 for ammo
				_on_weapon_changed(data.name, data.is_melee, data.weapon_icon)
				_on_ammo_changed(wh.get_current_mag(), wh.get_current_reserve(), data.is_melee, data.uses_battery)

func _process(delta):
	stamina_bar.value = lerp(stamina_bar.value, target_stamina, 15.0 * delta)
	_update_waypoints(delta)
	Engine.get_frames_per_second() # gives you the average of the last few frames
	var fps = Engine.get_frames_per_second()
	fps_label.text = "FPS: " + str(fps)
	
	# Change color based on performance
	if fps >= 60:
		fps_label.modulate = Color.GREEN
	elif fps >= 30:
		fps_label.modulate = Color.YELLOW
	else:
		fps_label.modulate = Color.RED

func _on_stamina_changed(new_value):
	target_stamina = new_value
	if target_stamina < 100.0:
		fade_timer.stop()
		stamina_container.modulate.a = 1.0 
	if target_stamina >= 100.0 and fade_timer.is_stopped():
		fade_timer.start()

func _fade_out_stamina():
	var tween = create_tween()
	tween.tween_property(stamina_container, "modulate:a", 0.0, 0.5)

# FIXED: Added uses_battery argument
func _on_ammo_changed(mag, reserve, is_melee, uses_battery):
	if is_melee:
		ammo_label.text = "---"
		reserve_label.text = "MEL"
	elif uses_battery:
		# Halo style battery percentage
		ammo_label.text = str(mag) + "%"
		reserve_label.text = "BAT"
	else:
		ammo_label.text = str(mag).pad_zeros(3)
		reserve_label.text = str(reserve).pad_zeros(3)

func _on_weapon_changed(w_name, is_melee, icon):
	weapon_name_label.text = str(w_name)
	if icon:
		_animate_main_icon(icon)
	else:
		weapon_icon.texture = null
	_update_weapon_stack()

func _animate_main_icon(new_icon):
	var tween = create_tween()
	weapon_icon.pivot_offset = weapon_icon.size / 2
	tween.tween_property(weapon_icon, "modulate:a", 0.0, 0.05)
	tween.tween_callback(func(): weapon_icon.texture = new_icon)
	tween.tween_property(weapon_icon, "modulate:a", 1.0, 0.05)
	weapon_icon.scale = Vector2(1.2, 1.2)
	tween.tween_property(weapon_icon, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_BACK)

func _update_weapon_stack():
	var player = get_tree().get_first_node_in_group("players")
	if not player: return
	var wh = player.find_child("WeaponHandler", true, false)
	if not wh: return

func set_interaction_prompt(text: String, show_prompt: bool, texture: Texture2D = null, fire_mode: String = "", ammo_type: String = ""):
	interaction_label.text = text
	interaction_prompt.visible = show_prompt
	
	if show_prompt:
		if texture:
			prompt_weapon_icon.texture = texture
			prompt_weapon_icon.visible = true
		else:
			prompt_weapon_icon.visible = false
			
		if fire_mode != "" or ammo_type != "":
			sub_details_label.text = (fire_mode + " | " + ammo_type).to_upper()
			sub_details_label.visible = true
		else:
			sub_details_label.visible = false
	else:
		prompt_weapon_icon.visible = false
		sub_details_label.visible = false

func _on_health_changed(new_value):
	var tween = create_tween()
	tween.tween_property(health_bar, "value", new_value, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if health_vignette and health_bar.max_value > 0:
		var health_percent = new_value / health_bar.max_value
		var target_a = 0.0
		
		# Start fading in at 50% health. At 25% health it will be 0.5 alpha, at 0% health it will be 1.0 alpha.
		if health_percent <= 0.5:
			target_a = clamp(1.0 - (health_percent / 0.5), 0.0, 1.0)
		
		if vignette_tween and vignette_tween.is_valid():
			vignette_tween.kill()
		vignette_tween = create_tween()
		
		# Tween the shader parameter directly instead of modulate, since the custom shader overrides modulate!
		vignette_tween.tween_property(health_vignette.material, "shader_parameter/intensity", target_a, 0.5)

func _update_waypoints(delta: float):
	if not waypoint_icon: return
	
	_waypoint_update_timer -= delta
	if _waypoint_update_timer <= 0.0:
		_waypoint_update_timer = 0.5 # update target every 0.5 seconds
		_cached_target_wp = null
		
		# Find active waypoints in the scene
		var waypoints = get_tree().get_nodes_in_group("objective_waypoints")
		for wp in waypoints:
			# If the SaveManager says this objective isn't done yet, point to it
			if SaveManager.game_data.objectives.has(wp.objective_id) and not SaveManager.game_data.objectives[wp.objective_id].done:
				_cached_target_wp = wp
				break
			
	if not is_instance_valid(_cached_target_wp):
		waypoint_icon.visible = false
		return
		
	var target_wp = _cached_target_wp
		
	var cam = get_viewport().get_camera_3d()
	if not cam: return
	
	waypoint_icon.visible = true
	var screen_pos = cam.unproject_position(target_wp.global_position)
	var is_behind = cam.is_position_behind(target_wp.global_position)
	var distance = cam.global_position.distance_to(target_wp.global_position)
	
	if distance < 5.0:
		waypoint_icon.visible = false
		return
	
	if waypoint_distance_label:
		waypoint_distance_label.text = str(int(distance)) + "m"
	
	var viewport_size = get_viewport().size
	var margin = 60.0
	
	if is_behind:
		# If behind, push it to the bottom edge
		screen_pos.y = viewport_size.y - margin
		screen_pos.x = viewport_size.x - screen_pos.x
	
	screen_pos.x = clamp(screen_pos.x, margin, viewport_size.x - margin)
	screen_pos.y = clamp(screen_pos.y, margin, viewport_size.y - margin)
	
	waypoint_icon.position = screen_pos - waypoint_icon.size / 2.0

func _on_armor_changed(new_value):
	if new_value < armor_bar.value:
		# --- TOOK DAMAGE ---
		# 1. Instantly snap the main green bar to the new lower health
		armor_bar.value = new_value
		
		# 2. Wait a split second, then smoothly tween the red catch-up bar down to match
		var tween = create_tween()
		tween.tween_interval(0.4) # The "hang time" where the red chunk stays visible
		tween.tween_property(armor_bar_catchup, "value", new_value, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	else:
		# --- HEALED ---
		# Instantly set both bars so the red doesn't accidentally peek out in front
		armor_bar.value = new_value
		armor_bar_catchup.value = new_value


func _on_objective_updated(_dummy_text: String):
	var active_description = "ALL OBJECTIVES COMPLETE"
	
	var all_objectives = SaveManager.game_data.objectives

	for id in all_objectives:
		var data = all_objectives[id]
		if not data["done"]:
			active_description = data["text"]
			break 
	
	objective_label.text = active_description
	
	var tween = create_tween()
	objective_label.pivot_offset = objective_label.size / 2 
	tween.tween_property(objective_label, "scale", Vector2(1.2, 1.2), 0.1)
	tween.parallel().tween_property(objective_label, "modulate", Color.CYAN, 0.1) 
	tween.tween_property(objective_label, "scale", Vector2(1.0, 1.0), 0.15)
	tween.parallel().tween_property(objective_label, "modulate", Color.WHITE, 0.15)

func display_status(message: String):
	if fade_tween:
		fade_tween.kill()
	
	status_text.text = message.to_upper()
	status_text.modulate.a = 1.0
	status_box.modulate.a = 1.0
	
	fade_tween = create_tween()
	fade_tween.tween_interval(show_status_duration)
	fade_tween.tween_property(status_text, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	fade_tween.tween_property(status_box, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)

func update_interact_progress(progress: float):
	if not interaction_prompt.visible: return
	
	if progress > 0.0:
		interaction_label.text = "HACKING... " + str(int(progress * 100)) + "%"
	else:
		interaction_label.text = "HOLD [E] TO OVERRIDE"

func update_grapple_cooldown(current_cooldown: float, max_cooldown: float):
	grapple_icon.max_value = max_cooldown
	
	if current_cooldown <= 0:
		grapple_icon.value = max_cooldown
		grapple_icon.tint_progress = Color(1.0, 1.0, 1.0, 1.0) 
	else:
		grapple_icon.value = max_cooldown - current_cooldown
		grapple_icon.tint_progress = Color(1.0, 1.0, 1.0, 0.6)

func update_double_jump_cooldown(current_cooldown: float, max_cooldown: float):
	if not double_jump_icon: return
	double_jump_icon.max_value = max_cooldown
	
	if current_cooldown <= 0:
		double_jump_icon.value = max_cooldown
		double_jump_icon.tint_progress = Color(1.0, 1.0, 1.0, 1.0) 
	else:
		double_jump_icon.value = max_cooldown - current_cooldown
		double_jump_icon.tint_progress = Color(1.0, 1.0, 1.0, 0.6)

func update_grenade_ui(current_charges: int, max_charges: int, timer: float, recharge_time: float):
	grenade_count_label.text = str(current_charges)
	
	if current_charges == max_charges:
		grenade_bar.value = grenade_bar.max_value 
	else:
		var fill_percentage = ((recharge_time - timer) / recharge_time) * grenade_bar.max_value
		grenade_bar.value = fill_percentage

# --- RELOAD UI ---
# --- RELOAD UI ---
var reload_tween: Tween

# Notice we added the is_overheat parameter here, defaulting to false
func _on_reload_started(duration: float, is_overheat: bool = false):
	if reload_tween and reload_tween.is_valid():
		reload_tween.kill()
		
	if not reload_bar: return
	
	var safe_duration = max(duration, 0.01) 
	
	reload_bar.visible = true
	reload_bar.max_value = 100.0
	reload_bar.modulate.a = 1.0
	
	reload_tween = create_tween()
	
	if is_overheat:
		# OVERHEAT: Start full, turn red, and drain to empty (cooling down)
		reload_bar.value = 0.0
		reload_bar.modulate = Color.RED
		reload_tween.tween_property(reload_bar, "value", 100.0, safe_duration).set_trans(Tween.TRANS_LINEAR)
	else:
		# NORMAL RELOAD: Start empty, stay white, and fill to full
		reload_bar.value = 0.0
		reload_bar.modulate = Color.WHITE
		reload_tween.tween_property(reload_bar, "value", 100.0, safe_duration).set_trans(Tween.TRANS_LINEAR)

func _on_heat_changed(current_heat: float, is_locked: bool):
	if not reload_bar: return
	
	# IMPORTANT: If the weapon hits 100% and locks up, we ignore this function!
	# Our _on_reload_started() Tween takes over here to handle the smooth Red draining animation.
	if is_locked:
		return 
		
	# Kill any active tweens so they don't fight our live heat updates
	if reload_tween and reload_tween.is_valid():
		reload_tween.kill()
		
	if current_heat > 0.0:
		reload_bar.visible = true
		reload_bar.modulate.a = 1.0
		reload_bar.max_value = 100.0
		
		# Snap the bar to the exact current heat percentage
		reload_bar.value = current_heat * 100.0
		
		# --- VISUAL POLISH ---
		# Make the bar turn orange when it gets dangerously close to overheating!
		if current_heat > 0.75:
			reload_bar.modulate = Color(1.0, 0.5, 0.0) # Orange
		else:
			reload_bar.modulate = Color.WHITE
			
	#else:
		## Hide the bar completely once the weapon has naturally cooled back down to 0%
		#reload_bar.visible = false
