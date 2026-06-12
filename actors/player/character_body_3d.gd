extends CharacterBody3D

# ─────────────────────────────────────────────
# SIGNALS & FSM
# ─────────────────────────────────────────────
signal stamina_changed(value)
signal health_changed(value)
signal armor_changed(value)
signal crosshair_state_changed(state: String)

enum State { IDLE, WALKING, SPRINTING, CROUCHING, SLIDING, IN_AIR, MANTLING, GRAPPLING }
var current_state: State = State.IDLE

# ─────────────────────────────────────────────
# EXPORTS (Fully Customizable in Inspector)
# ─────────────────────────────────────────────
@export_category("Player Stats")
@export var max_health: float = 100.0
@export var max_armor: float = 100.0
@export var mouse_sensitivity: float = 0.002

@export_category("Grenade")
@export var grenade_scene: PackedScene
@export var max_grenades: int = 2
@export var grenade_recharge_time: float = 8.0
@export var throw_force: float = 15.0
@export var throw_upward_force: float = 4.0

@export_category("Speeds")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var crouch_speed: float = 2.5
@export var slide_speed: float = 12.0
@export var jump_velocity: float = 4.5

@export_category("Movement Feel (AAA Snappiness)")
@export var ground_accel: float = 40.0       # Higher = reaches top speed faster
@export var ground_decel: float = 60.0       # Higher = stops on a dime (Halo feel)
@export var air_accel: float = 15.0          # How much control you have in the air
@export var air_decel: float = 5.0
@export var max_coyote_time: float = 0.15    # Seconds to jump after falling off a ledge
@export var max_jump_buffer: float = 0.1     # Seconds to remember a jump press before landing

@export_category("FOV & Camera")
@export var fov_base: float = 75.0
@export var fov_ads: float = 50.0
@export var fov_velocity_max_add: float = 12.0
@export var fov_velocity_ref_speed: float = 14.0
@export var fov_sprint_pulse: float = 5.0
@export var fov_sprint_pulse_decay: float = 6.0
@export var fov_lerp_speed: float = 8.0

@export_category("Landing & Camera Shake")
@export var land_thud_threshold_vel: float = 3.5
@export var land_light_trauma: float = 0.18
@export var land_heavy_trauma: float = 0.55
@export var land_cam_dip: float = 0.14
@export var land_cam_dip_speed: float = 14.0
@export var jump_cam_punch: float = 0.06
@export var jump_trauma_add: float = 0.12
@export var jump_punch_speed: float = 20.0

@export_category("Slide")
@export var slide_roll_deg: float = 4.0
@export var slide_roll_in_speed: float = 9.0
@export var slide_roll_out_speed: float = 6.0

@export_category("Grappling Hook")
@export var grapple_scene: PackedScene
@export var grapple_max_dist: float = 25.0
@export var grapple_speed: float = 28.0
@export var grapple_cooldown_time: float = 10.0

# ─────────────────────────────────────────────
# STATE VARIABLES & REFERENCES
# ─────────────────────────────────────────────
# --- Screen Shake ---
var trauma: float = 0.0
var noise = FastNoiseLite.new()
var time_elapsed: float = 0.0
var camera_base_pitch: float = 0.0

# --- Nodes ---
@onready var weapon_handler   = $Camera3D/CanvasLayer/SubViewportContainer/SubViewport/ViewModelCamera/WeaponHandler
@onready var viewmodel_camera = $Camera3D/CanvasLayer/SubViewportContainer/SubViewport/ViewModelCamera
@onready var main_camera      = $Camera3D
@onready var interact_ray     = $Camera3D/RayCast3D
@onready var footstep_snd     = $FootstepSound
@onready var slide_snd        = $SlideSound
@onready var armor_snd        = $ArmorRegenSound
@onready var health_snd       = $HealthRegenSound
@onready var grapple_snd      = $GrappleSound
@onready var ray_wall         = $MantleCheck/RayWall
@onready var ray_ledge        = $MantleCheck/RayLedge
@onready var pickup_area      = $PickupArea
@onready var ui               = get_tree().get_first_node_in_group("interface")
@onready var arc_dots         = $Camera3D/ThrowArc/ArcDots

# --- Stats ---
var health: float = 100.0
var armor: float = 0.0
var stamina: float = 100.0
const STAMINA_DRAIN = 5.0
const STAMINA_REGEN = 20.0

# --- Timers & Mechanics ---
var regen_timer: float = 0.0 # Used for Stamina delay
var combat_regen_timer: float = 0.0 # Used for Health/Armor delay
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var slide_timer: float = 0.0
var slide_vector: Vector2 = Vector2.ZERO
var mantle_timer: float = 0.0
var mantle_direction: Vector3 = Vector3.ZERO

var current_grenades: int = 2
var current_recharge_timer: float = 0.0
var grapple_cooldown: float = 0.0
var grapple_point: Vector3 = Vector3.ZERO
var grapple_rope: Node3D

var is_ads: bool = false
var has_control: bool = true
var current_interactable = null
var interact_timer: float = 0.0

const CROUCH_HEIGHT = 1.0
const STAND_HEIGHT  = 2.0
const BOB_FREQ = 2.4
const BOB_AMP  = 0.08
var t_bob = 0.0
var step_target = 0.0

# --- Camera Effects ---
var _was_on_floor: bool = false
var _vertical_vel_last_frame: float = 0.0
var _cam_dip_offset: float = 0.0
var _jump_cam_punch_cur: float = 0.0
var _slide_roll_cur: float = 0.0
var _fov_velocity_offset: float = 0.0
var _fov_sprint_pulse_cur: float = 0.0
var _last_crosshair_state = ""
const DEATH_SCREEN = preload("res://levels/death_screen.tscn")

# ─────────────────────────────────────────────
# READY
# ─────────────────────────────────────────────
func _ready():
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX

	health = max_health
	armor  = max_armor
	current_grenades = max_grenades
	await get_tree().process_frame
	health_changed.emit(health)
	armor_changed.emit(armor)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	pickup_area.body_entered.connect(_on_interactable_entered)
	pickup_area.body_exited.connect(_on_interactable_exited)

	if grapple_scene:
		grapple_rope = grapple_scene.instantiate()
		get_tree().root.call_deferred("add_child", grapple_rope)
		grapple_rope.visible = false

# ─────────────────────────────────────────────
# INPUT (Single-Press Actions)
# ─────────────────────────────────────────────
func _unhandled_input(event):
	if not has_control: return

	# Mouse Look
	if event is InputEventMouseMotion:
		var sens = mouse_sensitivity if not is_ads else mouse_sensitivity * 0.5
		rotate_y(-event.relative.x * sens)
		camera_base_pitch -= event.relative.y * sens
		camera_base_pitch = clamp(camera_base_pitch, -1.2, 1.2)
		weapon_handler.update_sway_input(event.relative)

	# Jump Buffering
	if event.is_action_pressed("ui_accept"):
		jump_buffer_timer = max_jump_buffer

	# Grapple
	if event.is_action_pressed("grapple") and grapple_cooldown <= 0 and current_state != State.GRAPPLING:
		fire_grapple()

	# Weapons
	if event.is_action_pressed("weapon_1"):    weapon_handler.switch_to("slot_1")
	if event.is_action_pressed("weapon_2"):    weapon_handler.switch_to("slot_2")
	if event.is_action_pressed("weapon_3"):    weapon_handler.switch_to("melee")
	if event.is_action_pressed("drop_weapon"): weapon_handler.drop_current_weapon()
	if event.is_action_pressed("reload"):      weapon_handler.begin_reload()

# ─────────────────────────────────────────────
# PHYSICS PROCESS (FSM Tick)
# ─────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not has_control:
		if not is_on_floor(): velocity += get_gravity() * delta
		velocity = velocity.move_toward(Vector3.ZERO, 20.0 * delta)
		move_and_slide()
		return

	time_elapsed += delta
	_update_timers(delta)
	_handle_landing()
	
	# Grenade Input (Held action for Arc)
	if Input.is_action_pressed("grenade"):
		draw_trajectory_arc()
	elif Input.is_action_just_released("grenade"):
		if current_grenades > 0: throw_grenade()
		if arc_dots: arc_dots.visible = false
	else:
		if arc_dots: arc_dots.visible = false

	is_ads = Input.is_action_pressed("ads")
	weapon_handler.set_ads(is_ads)

	# Execute FSM Logic
	match current_state:
		State.IDLE:       _state_idle(delta)
		State.WALKING:    _state_walking(delta)
		State.SPRINTING:  _state_sprinting(delta)
		State.CROUCHING:  _state_crouching(delta)
		State.SLIDING:    _state_sliding(delta)
		State.IN_AIR:     _state_in_air(delta)
		State.MANTLING:   _state_mantling(delta)
		State.GRAPPLING:  _state_grappling(delta)

	# Apply Gravity (if not in a state that overrides it)
	if not is_on_floor() and current_state not in [State.MANTLING, State.GRAPPLING]:
		velocity += get_gravity() * delta

	_execute_jump_logic()
	_check_mantle_trigger()

	move_and_slide()

	# Update Visuals & Post-Movement
	_update_fov(delta)
	_update_camera_effects(delta)
	_update_crosshair()
	_update_interaction_target(delta)
	_handle_regen(delta)
	sync_viewmodel_camera()

# ─────────────────────────────────────────────
# STATE MACHINE LOGIC
# ─────────────────────────────────────────────
func _change_state(new_state: State):
	current_state = new_state
	weapon_handler.set_sprinting(current_state == State.SPRINTING)
	weapon_handler.set_crouching(current_state == State.CROUCHING)
	
	# Handle Crouch Height Smoothly
	var target_height = CROUCH_HEIGHT if current_state in [State.CROUCHING, State.SLIDING] else STAND_HEIGHT
	var tween = create_tween()
	tween.tween_property($CollisionShape3D.shape, "height", target_height, 0.15)

func _state_idle(delta):
	_apply_ground_friction(delta)
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if not is_on_floor(): _change_state(State.IN_AIR)
	elif Input.is_key_pressed(KEY_CTRL): _change_state(State.CROUCHING)
	elif input_dir != Vector2.ZERO: _change_state(State.WALKING)

func _state_walking(delta):
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_apply_ground_movement(input_dir, walk_speed, delta)
	_handle_headbob(delta)
	
	var is_moving_forward = input_dir.y < -0.3
	if not is_on_floor(): _change_state(State.IN_AIR)
	elif Input.is_key_pressed(KEY_CTRL): _change_state(State.CROUCHING)
	elif input_dir == Vector2.ZERO: _change_state(State.IDLE)
	elif Input.is_key_pressed(KEY_SHIFT) and stamina > 0 and is_moving_forward and not is_ads:
		_change_state(State.SPRINTING)
		_fov_sprint_pulse_cur = fov_sprint_pulse

func _state_sprinting(delta):
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_apply_ground_movement(input_dir, sprint_speed, delta)
	_handle_headbob(delta)

	stamina -= STAMINA_DRAIN * delta
	regen_timer = 2.0 # Delay before stamina regen
	stamina_changed.emit(clamp(stamina, 0.0, 100.0))

	if not is_on_floor(): _change_state(State.IN_AIR)
	elif input_dir.y > -0.1 or stamina <= 0 or is_ads: _change_state(State.WALKING)
	elif Input.is_action_just_pressed("ui_crouch"): 
		slide_timer = 1.0
		slide_vector = input_dir
		stamina -= 20.0
		if slide_snd: slide_snd.play()
		_change_state(State.SLIDING)

func _state_crouching(delta):
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_apply_ground_movement(input_dir, crouch_speed, delta)
	_handle_headbob(delta)

	if not is_on_floor(): _change_state(State.IN_AIR)
	elif not Input.is_key_pressed(KEY_CTRL):
		_change_state(State.WALKING if input_dir != Vector2.ZERO else State.IDLE)

func _state_sliding(delta):
	slide_timer -= delta
	var slide_dir_3d = (transform.basis * Vector3(slide_vector.x, 0.0, slide_vector.y)).normalized()
	var current_slide_speed = slide_speed * (slide_timer) # Decays over time
	
	var current_xz = Vector2(velocity.x, velocity.z)
	var target_xz = Vector2(slide_dir_3d.x, slide_dir_3d.z) * current_slide_speed
	current_xz = current_xz.move_toward(target_xz, ground_decel * delta)
	
	velocity.x = current_xz.x
	velocity.z = current_xz.y

	if not is_on_floor(): 
		if slide_snd and slide_snd.playing: slide_snd.stop()
		_change_state(State.IN_AIR)
	elif slide_timer <= 0.0 or velocity.length() < 1.0 or not Input.is_key_pressed(KEY_CTRL):
		if slide_snd and slide_snd.playing: slide_snd.stop()
		_change_state(State.CROUCHING if Input.is_key_pressed(KEY_CTRL) else State.IDLE)

func _state_in_air(delta):
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var current_xz = Vector2(velocity.x, velocity.z)
	var target_xz = Vector2(direction.x, direction.z) * walk_speed
	
	# Use move_toward for air control. Accelerate if moving towards input, drift if letting go.
	var accel = air_accel if direction.length() > 0 else air_decel
	current_xz = current_xz.move_toward(target_xz, accel * delta)
	
	velocity.x = current_xz.x
	velocity.z = current_xz.y

	if is_on_floor():
		_change_state(State.IDLE) # Landing logic determines exact follow-up state

func _state_mantling(delta):
	mantle_timer -= delta
	if mantle_timer > 0.2:
		# First half: pull up vertically
		velocity = Vector3.UP * 6.0
	else:
		# Second half: push forward over the ledge
		velocity = mantle_direction * 5.0
		velocity.y = 0

	if mantle_timer <= 0:
		_change_state(State.IDLE)

func _state_grappling(delta):
	var to_point = grapple_point - global_position
	if to_point.length() < 2.0 or Input.is_action_just_pressed("ui_crouch"):
		break_grapple()
	else:
		velocity = velocity.move_toward(to_point.normalized() * grapple_speed, 40.0 * delta)
		update_grapple_visuals()
		
		# Slingshot jump out of grapple
		if Input.is_action_just_pressed("ui_accept"):
			var pull_dir = (grapple_point - global_position).normalized()
			var look_dir = -main_camera.global_transform.basis.z
			velocity = (pull_dir + look_dir).normalized() * (grapple_speed * 1.2)
			velocity.y = jump_velocity * 2.2
			break_grapple()

# ─────────────────────────────────────────────
# CORE MOVEMENT MECHANICS
# ─────────────────────────────────────────────
func _apply_ground_movement(input_dir: Vector2, target_speed: float, delta: float):
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var current_xz = Vector2(velocity.x, velocity.z)
	var target_xz = Vector2(direction.x, direction.z) * target_speed
	
	# Snappy movement: use move_toward instead of lerp
	var accel = ground_accel if input_dir.length() > 0 else ground_decel
	current_xz = current_xz.move_toward(target_xz, accel * delta)
	
	velocity.x = current_xz.x
	velocity.z = current_xz.y

func _apply_ground_friction(delta: float):
	var current_xz = Vector2(velocity.x, velocity.z)
	current_xz = current_xz.move_toward(Vector2.ZERO, ground_decel * delta)
	velocity.x = current_xz.x
	velocity.z = current_xz.y

func _execute_jump_logic():
	# If buffer has time and coyote has time, jump!
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = jump_velocity
		_jump_cam_punch_cur = jump_cam_punch
		trauma += jump_trauma_add
		trauma = clamp(trauma, 0.0, 1.0)
		
		jump_buffer_timer = 0.0 # Consume timers
		coyote_timer = 0.0
		_change_state(State.IN_AIR)

func _check_mantle_trigger():
	if current_state == State.MANTLING or current_state == State.GRAPPLING: return
	if not ray_wall.is_colliding() or ray_ledge.is_colliding(): return
	if not Input.is_action_just_pressed("ui_accept"): return

	var wall_normal = ray_wall.get_collision_normal()
	var facing = -transform.basis.z
	if wall_normal.dot(facing) > -0.3: return

	# Trigger Physics-Based Mantle
	mantle_direction = -wall_normal
	mantle_timer = 0.4
	_cam_dip_offset = -0.08
	_change_state(State.MANTLING)

func _handle_landing():
	var just_landed = not _was_on_floor and is_on_floor()
	if just_landed:
		var impact = abs(_vertical_vel_last_frame)
		if impact > land_thud_threshold_vel:
			var intensity = clamp((impact - land_thud_threshold_vel) / 10.0, 0.0, 1.0)
			trauma += lerp(land_light_trauma, land_heavy_trauma, intensity)
			trauma = clamp(trauma, 0.0, 1.0)
			_cam_dip_offset = -land_cam_dip * intensity
			
			if intensity > 0.5: # Heavy landing penalty
				velocity.x *= 0.5
				velocity.z *= 0.5
	
	_was_on_floor = is_on_floor()
	if not is_on_floor(): _vertical_vel_last_frame = velocity.y

func _update_timers(delta):
	# Coyote Time
	if is_on_floor(): coyote_timer = max_coyote_time
	else: coyote_timer -= delta

	# Jump Buffer
	if jump_buffer_timer > 0: jump_buffer_timer -= delta
	
	# Grapple
	if grapple_cooldown > 0: grapple_cooldown -= delta
	if ui and ui.has_method("update_grapple_cooldown"):
		ui.update_grapple_cooldown(grapple_cooldown, grapple_cooldown_time)

	# Stamina Regen
	if current_state != State.SPRINTING:
		if regen_timer > 0: regen_timer -= delta
		else: 
			stamina += (STAMINA_REGEN * 2.0 if current_state == State.CROUCHING else STAMINA_REGEN) * delta
			stamina = clamp(stamina, 0.0, 100.0)
			stamina_changed.emit(stamina)

	# Grenades
	if current_grenades < max_grenades:
		current_recharge_timer -= delta
		if current_recharge_timer <= 0:
			current_grenades += 1
			if current_grenades < max_grenades: current_recharge_timer = grenade_recharge_time
	if ui and ui.has_method("update_grenade_ui"):
		ui.update_grenade_ui(current_grenades, max_grenades, current_recharge_timer, grenade_recharge_time)

# ─────────────────────────────────────────────
# CAMERA & VISUALS
# ─────────────────────────────────────────────
func _update_fov(delta: float) -> void:
	_fov_sprint_pulse_cur = move_toward(_fov_sprint_pulse_cur, 0.0, fov_sprint_pulse_decay * delta)
	var flat_speed = Vector3(velocity.x, 0.0, velocity.z).length()
	var speed_t = clamp(flat_speed / fov_velocity_ref_speed, 0.0, 1.0)
	speed_t = speed_t * speed_t 
	
	var target_vel_offset = 0.0 if is_ads else (speed_t * fov_velocity_max_add)
	_fov_velocity_offset = lerp(_fov_velocity_offset, target_vel_offset, fov_lerp_speed * delta)

	var base_fov = fov_ads if is_ads else fov_base
	$Camera3D.fov = lerp($Camera3D.fov, base_fov + _fov_velocity_offset + _fov_sprint_pulse_cur, fov_lerp_speed * delta)

func _update_camera_effects(delta: float):
	# Camera Dip & Punch
	_cam_dip_offset = lerp(_cam_dip_offset, 0.0, land_cam_dip_speed * delta)
	_jump_cam_punch_cur = lerp(_jump_cam_punch_cur, 0.0, jump_punch_speed * delta)
	
	var target_cam_y = 0.5 if current_state not in [State.CROUCHING, State.SLIDING] else -0.2
	var bob_offset = sin(t_bob * BOB_FREQ) * BOB_AMP if t_bob > 0 else 0.0
	
	$Camera3D.position.y = lerp($Camera3D.position.y, target_cam_y + bob_offset + _cam_dip_offset + _jump_cam_punch_cur, 10.0 * delta)

	# Slide Roll
	var slide_roll_target = deg_to_rad(slide_roll_deg) if current_state == State.SLIDING else 0.0
	var roll_speed = slide_roll_in_speed if current_state == State.SLIDING else slide_roll_out_speed
	_slide_roll_cur = lerp(_slide_roll_cur, slide_roll_target, roll_speed * delta)

	# Screen Shake
	var shake_roll = 0.0; var shake_pitch = 0.0; var shake_yaw = 0.0
	if trauma > 0.0:
		trauma = max(trauma - 1.5 * delta, 0.0)
		var sq = trauma * trauma
		shake_yaw   = noise.get_noise_2d(time_elapsed * 50.0, 0.0) * 0.05 * sq
		shake_pitch = noise.get_noise_2d(0.0, time_elapsed * 50.0) * 0.05 * sq
		shake_roll  = noise.get_noise_2d(time_elapsed * 50.0, time_elapsed * 50.0) * 0.05 * sq

	$Camera3D.rotation.z = _slide_roll_cur + shake_roll
	$Camera3D.rotation.y = shake_yaw
	$Camera3D.rotation.x = camera_base_pitch + shake_pitch
	$TargetPoint.position.y = $Camera3D.position.y

func _handle_headbob(delta):
	if is_on_floor() and velocity.length() > 1.1:
		t_bob += delta * velocity.length()
		step_target -= delta
		if step_target <= 0.0:
			play_footstep()
			step_target = 0.005 if current_state == State.SPRINTING else (0.9 if current_state == State.CROUCHING else 0.55)
	else:
		t_bob = 0.0
		step_target = 0.0

func _update_crosshair():
	var state = "normal"
	if is_ads: state = "ads"
	elif current_state in [State.SPRINTING, State.SLIDING]: state = "sprint"
	elif current_state == State.CROUCHING: state = "crouch"
	
	if state != _last_crosshair_state:
		_last_crosshair_state = state
		crosshair_state_changed.emit(state)

# ─────────────────────────────────────────────
# ABILITIES (Grapple & Grenade)
# ─────────────────────────────────────────────
func fire_grapple():
	var space_state = get_world_3d().direct_space_state
	var aim_dir = -main_camera.global_transform.basis.z
	var start = main_camera.global_position
	var max_reach_point = start + aim_dir * grapple_max_dist
	
	# Cast the ray forward to check for surfaces
	var query = PhysicsRayQueryParameters3D.create(start, max_reach_point, 1)
	query.exclude = [self.get_rid()]
	var result = space_state.intersect_ray(query)
	
	# If we hit a wall, hook the wall. If we hit nothing, hook the air at max distance!
	if result:
		grapple_point = result.position
	else:
		grapple_point = max_reach_point
		
	# Always activate the grapple now!
	grapple_cooldown = grapple_cooldown_time
	grapple_rope.visible = true
	
	# Give the player a slight upward boost to start the swing
	velocity.y += 5.0 
	
	if grapple_snd: 
		grapple_snd.play()
		
	_change_state(State.GRAPPLING)

func break_grapple():
	if is_instance_valid(grapple_rope): grapple_rope.visible = false
	if current_state == State.GRAPPLING: _change_state(State.IN_AIR)

func update_grapple_visuals():
	if not is_instance_valid(grapple_rope): return
	var gun_tip = main_camera.global_position + (-main_camera.global_transform.basis.z * 0.5) + (main_camera.global_transform.basis.y * -0.2) + (main_camera.global_transform.basis.x * 0.3)
	grapple_rope.global_position = gun_tip
	grapple_rope.look_at(grapple_point, Vector3.UP)
	if grapple_rope.has_method("update_length"):
		grapple_rope.update_length(gun_tip.distance_to(grapple_point))

func draw_trajectory_arc():
	if current_grenades <= 0: return
	arc_dots.visible = true
	var gravity = Vector3.DOWN * ProjectSettings.get_setting("physics/3d/default_gravity")
	var current_pos = arc_dots.global_position
	var vel = (-$Camera3D.global_transform.basis.z * throw_force) + (Vector3.UP * throw_upward_force)
	var time_step = 0.1 
	
	for i in range(arc_dots.multimesh.instance_count):
		var local_pos = arc_dots.to_local(current_pos)
		arc_dots.multimesh.set_instance_transform(i, Transform3D().translated(local_pos))
		vel += gravity * time_step
		current_pos += vel * time_step

func throw_grenade():
	current_grenades -= 1
	if current_recharge_timer <= 0: current_recharge_timer = grenade_recharge_time 
	var nade = grenade_scene.instantiate()
	get_tree().root.add_child(nade)
	nade.global_position = $Camera3D.global_position
	nade.linear_velocity = (-$Camera3D.global_transform.basis.z * throw_force) + (Vector3.UP * throw_upward_force)

# ─────────────────────────────────────────────
# INTERACTION & UTILITY
# ─────────────────────────────────────────────
func _update_interaction_target(delta: float):
	var new_target = null
	if interact_ray.is_colliding():
		var hit = interact_ray.get_collider()
		var target = hit
		if target and not target.has_method("interact"):
			if target.get_parent() and target.get_parent().has_method("interact"): target = target.get_parent()
			elif target.owner and target.owner.has_method("interact"): target = target.owner
		if target and target.has_method("interact"): new_target = target

	if new_target != current_interactable:
		current_interactable = new_target
		interact_timer = 0.0 
		_update_ui_prompt()

	if current_interactable:
		var required_time = current_interactable.get("hold_time") if "hold_time" in current_interactable else 0.0
		if required_time > 0:
			if Input.is_action_pressed("interact"):
				interact_timer += delta
				if ui and ui.has_method("update_interact_progress"): ui.update_interact_progress(interact_timer / required_time)
				if interact_timer >= required_time:
					current_interactable.interact(self)
					current_interactable = null
					interact_timer = 0.0
			else:
				interact_timer = 0.0
				if ui and ui.has_method("update_interact_progress"): ui.update_interact_progress(0.0)
		else:
			if Input.is_action_just_pressed("interact"): current_interactable.interact(self)

func _update_ui_prompt():
	if ui and ui.has_method("set_interaction_prompt"):
		if current_interactable:
			var text = current_interactable.get("prompt_text") if "prompt_text" in current_interactable else "INTERACT"
			var hold = current_interactable.get("hold_time") if "hold_time" in current_interactable else 0.0
			ui.set_interaction_prompt(("HOLD [E] TO " if hold > 0 else "PRESS [E] TO ") + text, true)
		else:
			ui.set_interaction_prompt("", false)

func play_footstep():
	if not footstep_snd.playing:
		footstep_snd.pitch_scale = randf_range(0.9, 1.1)
		footstep_snd.volume_db = 2.0 if current_state == State.SPRINTING else (-15.0 if current_state == State.CROUCHING else -5.0)
		footstep_snd.play()

func sync_viewmodel_camera():
	viewmodel_camera.global_transform = main_camera.global_transform
	viewmodel_camera.fov = main_camera.fov

func _on_interactable_entered(body): pass # Simplified via raycast updates
func _on_interactable_exited(body): pass

# ─────────────────────────────────────────────
# COMBAT & REGEN LOGIC
# ─────────────────────────────────────────────
func take_damage(amount: float) -> void:
	if health <= 0: return # Already dead
	
	# Apply damage to armor first, spill over to health
	if armor > 0:
		armor -= amount
		if armor < 0:
			health += armor # Armor went below 0, subtract the remainder from health
			armor = 0
	else:
		health -= amount

	# Update UI
	health_changed.emit(health)
	armor_changed.emit(armor)

	# Flinch the camera
	trauma += 0.35
	trauma = clamp(trauma, 0.0, 1.0)
	
	# Reset combat regen timer so they don't heal while being shot
	combat_regen_timer = 5.0 

	if health <= 0:
		die()

func _handle_regen(delta: float):
	if health <= 0: return # Don't regen a corpse
	
	if combat_regen_timer > 0:
		combat_regen_timer -= delta
		
		# Stop looping sounds if we took damage and the timer resets
		if armor_snd and armor_snd.playing: armor_snd.stop()
		if health_snd and health_snd.playing: health_snd.stop()
		
	else:
		var is_healing = false
		
		# 1. Regenerate Health first (if below max)
		if health < max_health:
			health = move_toward(health, max_health, 10.0 * delta)
			health_changed.emit(health)
			is_healing = true
			if health_snd and not health_snd.playing: health_snd.play()
			
		# 2. Regenerate Armor next (if health is full)
		elif armor < max_armor:
			if health_snd and health_snd.playing: health_snd.stop()
			armor = move_toward(armor, max_armor, 25.0 * delta)
			armor_changed.emit(armor)
			is_healing = true
			if armor_snd and not armor_snd.playing: armor_snd.play()
			
		# 3. Fully healed, silence the audio
		if not is_healing:
			if armor_snd and armor_snd.playing: armor_snd.stop()
			if health_snd and health_snd.playing: health_snd.stop()

func die() -> void:
	has_control = false
	health = 0
	health_changed.emit(health)
	
	# Transition to your death screen
	if DEATH_SCREEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_packed(DEATH_SCREEN)
	else:
		print("Player died, but no DEATH_SCREEN packed scene is set!")
