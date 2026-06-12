extends CharacterBody3D

# =============================================================================
#  DRONE AI - AAA BEHAVIOUR REWRITE
#  States: idle → patrol → alert → search → attack → suppress → disengage
# =============================================================================

# ---------------------------------------------------------------------------
#  EXPORTS
# ---------------------------------------------------------------------------
@export_group("Combat Stats")
@export var health: float          = 150.0
@export var damage: float          = 3.0

@export_group("Fire Rate / Windup")
@export var windup_delay: float    = 1.0   # Seconds of LOS before first shot
@export var min_fire_rate: float   = 0.5   # Slow starting fire rate
@export var max_fire_rate: float   = 0.08  # Fastest possible fire rate
@export var fire_rate_accel: float = 0.06  # Speedup per shot

@export_group("AI Ranges")
@export var detection_range: float    = 45.0
@export var max_attack_range: float   = 20.0
@export var min_attack_range: float   = 15.0
@export var disengage_range: float    = 55.0  # Gives up chase beyond this

@export_group("Search Behaviour")
@export var search_duration: float    = 6.0   # Seconds to hunt before giving up
@export var search_sweep_speed: float = 1.8   # Radians/sec during look-around
@export var search_move_speed: float  = 4.0   # Slow creep toward last known pos
@export var suppress_burst_count: int = 5     # Shots fired blind when LOS breaks

@export_group("Patrol")
@export var patrol_points: Array[NodePath] = []
@export var patrol_wait_time: float = 2.0     # Pause at each waypoint

@export_group("Narrative")
@export var unit_name: String             = ""
@export var detection_message: String     = "Intruder detected!"
@export var search_bark: String           = "Last position locked. Searching…"
@export var disengage_bark: String        = "Target lost. Resuming patrol."
@export var suppress_bark: String         = "Suppressing position!"

@export_group("Movement Stats")
@export var move_speed: float      = 6.0
@export var hover_height: float    = 2.5
@export var rotation_speed: float  = 5.0
@export var dodge_speed: float     = 12.0

# ---------------------------------------------------------------------------
#  NODE REFERENCES
# ---------------------------------------------------------------------------
@onready var nav_agent    = $NavigationAgent3D
@onready var ray          = $DroneModel/RayCast3D
@onready var laser_mesh   = $DroneModel/RayCast3D/MeshInstance3D
@onready var muzzle_flash = $DroneModel/Muzzle/MuzzleFlash
@onready var shoot_sound  = $DroneModel/Muzzle/ShootSound
@onready var flash_light  = $DroneModel/Muzzle/OmniLight3D
@onready var explode_audio = $AudioStreamPlayer3D

# ---------------------------------------------------------------------------
#  LASER COLOUR PALETTE 
# ---------------------------------------------------------------------------
const COLOR_IDLE       = Color(0.2, 0.5, 1.0, 0.15)
const COLOR_ALERT      = Color(1.0, 0.7, 0.0, 0.6)
const COLOR_SEARCH     = Color(1.0, 0.4, 0.0, 0.7)
const COLOR_WINDUP     = Color(1.0, 0.0, 0.0, 0.4)
const COLOR_ATTACK     = Color(1.0, 0.0, 0.0, 1.0)
const COLOR_SUPPRESS   = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_DISENGAGE  = Color(0.2, 0.5, 1.0, 0.3)

# ---------------------------------------------------------------------------
#  STATE MACHINE
# ---------------------------------------------------------------------------
enum State {
	IDLE,
	PATROL,
	ALERT,       
	SEARCH,      
	ATTACK,
	SUPPRESS,    
	DISENGAGE,   
	DEAD
}

var state: State = State.IDLE

# ---------------------------------------------------------------------------
#  RUNTIME VARS
# ---------------------------------------------------------------------------
var player: Node3D       = null
var can_shoot: bool      = true

# Detection / sight
var has_detected_player: bool  = false
var time_in_sight: float       = 0.0
var time_out_of_sight: float   = 0.0
var last_known_position: Vector3 = Vector3.ZERO

# Fire rate
var current_fire_rate: float   = 0.5
var current_target_offset: Vector3 = Vector3.ZERO

# Dodge
var dodge_timer: float         = 0.0
var dodge_direction: Vector3   = Vector3.ZERO

# Search sweep
var search_timer: float        = 0.0
var search_sweep_angle: float  = 0.0
var search_arrived: bool       = false

# Suppress
var suppress_shots_remaining: int = 0

# Alert
var alert_timer: float         = 0.0
const ALERT_DURATION: float    = 0.8

# Patrol
var patrol_nodes: Array[Node3D] = []
var patrol_index: int           = 0
var patrol_wait_timer: float    = 0.0
var patrol_waiting: bool        = false

# ---------------------------------------------------------------------------
#  READY
# ---------------------------------------------------------------------------
func _ready() -> void:
	add_to_group("drones")
	player = get_tree().get_first_node_in_group("players")
	current_fire_rate = min_fire_rate
	ray.target_position = Vector3(0, 0, -detection_range)

	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 1.0

	for path in patrol_points:
		var n = get_node_or_null(path)
		if n:
			patrol_nodes.append(n)

	if patrol_nodes.size() > 0:
		state = State.PATROL
	else:
		state = State.IDLE

	laser_mesh.visible = false

# ---------------------------------------------------------------------------
#  PHYSICS PROCESS
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_process_dead(delta)
		return

	if player == null:
		player = get_tree().get_first_node_in_group("players")
		if player == null:
			return

	var dist: float = global_position.distance_to(player.global_position)
	var has_los: bool = _check_los()

	# Dodge override
	if dodge_timer > 0.0:
		dodge_timer -= delta
		velocity = velocity.lerp(dodge_direction * dodge_speed, 8.0 * delta)
		_aim_at_player(delta)
		move_and_slide()
		_update_laser_visuals()
		return

	if has_los:
		last_known_position = player.global_position
		time_in_sight      += delta
		time_out_of_sight   = 0.0
	else:
		time_out_of_sight  += delta
		time_in_sight       = 0.0

	match state:
		State.IDLE:      _state_idle(delta, dist, has_los)
		State.PATROL:    _state_patrol(delta, dist, has_los)
		State.ALERT:     _state_alert(delta, dist, has_los)
		State.SEARCH:    _state_search(delta)
		State.ATTACK:    _state_attack(delta, dist, has_los)
		State.SUPPRESS:  _state_suppress(delta)
		State.DISENGAGE: _state_disengage(delta)

	velocity.y += sin(Time.get_ticks_msec() * 0.003) * 0.05
	move_and_slide()
	_update_laser_visuals()

# ---------------------------------------------------------------------------
#  STATE HANDLERS
# ---------------------------------------------------------------------------

func _state_idle(delta: float, dist: float, has_los: bool) -> void:
	velocity = velocity.lerp(Vector3.ZERO, 3.0 * delta)
	_set_laser_visible(false)
	if has_los and dist < detection_range:
		_enter_alert()

func _state_patrol(delta: float, dist: float, has_los: bool) -> void:
	_set_laser_color(COLOR_IDLE, 4.0)
	laser_mesh.visible = true

	if has_los and dist < detection_range:
		_enter_alert()
		return

	if patrol_nodes.is_empty():
		state = State.IDLE
		return

	if patrol_waiting:
		patrol_wait_timer -= delta
		velocity = velocity.lerp(Vector3.ZERO, 3.0 * delta)
		if patrol_wait_timer <= 0.0:
			patrol_waiting = false
			patrol_index = (patrol_index + 1) % patrol_nodes.size()
		return

	var target_pos: Vector3 = patrol_nodes[patrol_index].global_position
	nav_agent.target_position = target_pos
	
	# Look where we're going during patrol
	_aim_at_position(target_pos, delta)
	_fly_toward_nav(delta, move_speed * 0.6)

	if global_position.distance_to(target_pos) < 1.5:
		patrol_waiting    = true
		patrol_wait_timer = patrol_wait_time

func _state_alert(delta: float, dist: float, has_los: bool) -> void:
	alert_timer -= delta
	velocity = velocity.lerp(Vector3.ZERO, 4.0 * delta)
	_set_laser_color(COLOR_ALERT, 15.0 * abs(sin(Time.get_ticks_msec() * 0.005)))
	laser_mesh.visible = true
	
	_aim_at_player(delta)

	if not has_los:
		_enter_search()
		return

	if alert_timer <= 0.0:
		_enter_attack()

func _state_attack(delta: float, dist: float, has_los: bool) -> void:
	if dist > disengage_range:
		_enter_disengage()
		return

	if not has_los:
		_enter_suppress()
		return

	_combat_movement(delta, dist)
	_aim_at_player(delta)
	_handle_laser_and_shooting(delta)

func _state_suppress(delta: float) -> void:
	_set_laser_color(COLOR_SUPPRESS, 30.0)
	laser_mesh.visible = true
	velocity = velocity.lerp(Vector3.ZERO, 4.0 * delta)
	_aim_at_position(last_known_position, delta)

func _state_search(delta: float) -> void:
	search_timer -= delta
	_set_laser_color(COLOR_SEARCH, 12.0)
	laser_mesh.visible = true

	if _check_los():
		_enter_alert()
		return

	if search_timer <= 0.0:
		_enter_disengage()
		return

	if not search_arrived:
		nav_agent.target_position = last_known_position
		_fly_toward_nav(delta, search_move_speed)
		_aim_at_position(last_known_position, delta)
		
		if global_position.distance_to(last_known_position) < 2.0:
			search_arrived = true
	else:
		velocity = velocity.lerp(Vector3.ZERO, 3.0 * delta)
		search_sweep_angle += search_sweep_speed * delta
		var sweep_dir = Vector3(sin(search_sweep_angle), 0.0, cos(search_sweep_angle))
		var target_basis = Basis.looking_at(sweep_dir, Vector3.UP)
		$DroneModel.global_basis = $DroneModel.global_basis.orthonormalized().slerp(
			target_basis, rotation_speed * delta
		)

func _state_disengage(delta: float) -> void:
	_set_laser_color(COLOR_DISENGAGE, 4.0)
	laser_mesh.visible = true
	velocity = velocity.lerp(Vector3.ZERO, 2.0 * delta)

	if _check_los() and global_position.distance_to(player.global_position) < detection_range:
		_enter_alert()
		return

	await get_tree().create_timer(2.0).timeout
	if state == State.DISENGAGE:
		if patrol_nodes.size() > 0:
			state = State.PATROL
		else:
			state = State.IDLE

# ---------------------------------------------------------------------------
#  STATE TRANSITION HELPERS
# ---------------------------------------------------------------------------

func _enter_alert() -> void:
	state       = State.ALERT
	alert_timer = ALERT_DURATION
	if not has_detected_player:
		has_detected_player = true
		if SubtitleManager and unit_name != "":
			SubtitleManager.show_subtitle(unit_name, detection_message, 3.5)

func _enter_attack() -> void:
	state             = State.ATTACK
	time_in_sight     = 0.0
	current_fire_rate = min_fire_rate

func _enter_suppress() -> void:
	state                    = State.SUPPRESS
	suppress_shots_remaining = suppress_burst_count
	if SubtitleManager and unit_name != "":
		SubtitleManager.show_subtitle(unit_name, suppress_bark, 2.0)
	_run_suppress_coroutine()

func _enter_search() -> void:
	state          = State.SEARCH
	search_timer   = search_duration
	search_arrived = false
	search_sweep_angle = 0.0
	_reset_combat_spool()
	if SubtitleManager and unit_name != "":
		SubtitleManager.show_subtitle(unit_name, search_bark, 3.5)

func _enter_disengage() -> void:
	state = State.DISENGAGE
	_reset_combat_spool()
	if SubtitleManager and unit_name != "":
		SubtitleManager.show_subtitle(unit_name, disengage_bark, 3.0)

# ---------------------------------------------------------------------------
#  SUPPRESS COROUTINE
# ---------------------------------------------------------------------------
func _run_suppress_coroutine() -> void:
	for i in suppress_burst_count:
		if state != State.SUPPRESS:
			return
		_fire_blind_shot()
		await get_tree().create_timer(0.15).timeout

	if state == State.SUPPRESS:
		_enter_search()

func _fire_blind_shot() -> void:
	if muzzle_flash: muzzle_flash.restart()
	if shoot_sound:
		shoot_sound.pitch_scale = randf_range(0.9, 1.1)
		shoot_sound.play()
	if flash_light:
		flash_light.visible = true
		get_tree().create_timer(0.05).timeout.connect(
			func(): if is_instance_valid(flash_light): flash_light.visible = false
		)

# ---------------------------------------------------------------------------
#  MOVEMENT
# ---------------------------------------------------------------------------

func _fly_toward_nav(delta: float, speed: float) -> void:
	var next_pos  = nav_agent.get_next_path_position()
	var dir       = (next_pos - global_position)
	dir.y         = 0.0
	
	if dir.length_squared() > 0.001:
		dir = dir.normalized()
	else:
		dir = Vector3.ZERO

	# Prevent floor-diving if there is no last_known_position yet
	var target_y: float
	if state == State.PATROL and patrol_nodes.size() > 0:
		target_y = patrol_nodes[patrol_index].global_position.y
	else:
		target_y = last_known_position.y + hover_height if last_known_position != Vector3.ZERO else global_position.y

	var vert_pull = (target_y - global_position.y) * 2.0
	var desired   = dir * speed
	desired.y     = vert_pull
	velocity      = velocity.lerp(desired, 4.0 * delta)

func _combat_movement(delta: float, dist: float) -> void:
	var to_player   = (player.global_position - global_position).normalized()
	var desired     = Vector3.ZERO

	if dist < min_attack_range:
		desired = -to_player * move_speed
	elif dist > max_attack_range:
		desired = to_player * move_speed

	var right        = to_player.cross(Vector3.UP).normalized()
	var strafe       = sin(Time.get_ticks_msec() * 0.001) * (move_speed * 0.6)
	desired         += right * strafe

	desired.y        = (player.global_position.y + hover_height - global_position.y) * 2.0
	velocity         = velocity.lerp(desired, 3.0 * delta)

# ---------------------------------------------------------------------------
#  AIMING REWRITE
# ---------------------------------------------------------------------------

func _aim_at_player(delta: float) -> void:
	var target_node = player.get_node_or_null("TargetPoint")
	var aim_pos     = target_node.global_position if target_node else player.global_position + Vector3(0, 1.2, 0)
	_aim_at_position(aim_pos, delta)
	
func _aim_at_position(target_pos: Vector3, delta: float) -> void:
	var final_aim = target_pos + current_target_offset

	# Body faces player (horizontal only)
	var body_dir = final_aim - global_position
	body_dir.y   = 0.0
	if body_dir.length_squared() > 0.001:
		var tb = Basis.looking_at(body_dir.normalized(), Vector3.UP)
		$DroneModel.global_basis = $DroneModel.global_basis.orthonormalized().slerp(
			tb, rotation_speed * delta
		)

	# Ray tracks vertically too, smoothly following target
	var ray_dir = final_aim - ray.global_position
	if ray_dir.length_squared() > 0.001:
		var rb = Basis.looking_at(ray_dir.normalized(), Vector3.UP)
		ray.global_basis = ray.global_basis.orthonormalized().slerp(
			rb, rotation_speed * 3.0 * delta
		)

# ---------------------------------------------------------------------------
#  LASER, LOS CHECK, SHOOTING
# ---------------------------------------------------------------------------

func _check_los() -> bool:
	if not is_instance_valid(player):
		return false
		
	var space_state = get_world_3d().direct_space_state
	var target_node = player.get_node_or_null("TargetPoint")
	var target_pos  = target_node.global_position if target_node else player.global_position + Vector3(0, 1.2, 0)
	
	var origin = ray.global_position if is_instance_valid(ray) else global_position
	var query  = PhysicsRayQueryParameters3D.create(origin, target_pos)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	if result and is_instance_valid(result.collider):
		return result.collider == player or result.collider.is_in_group("players")
		
	return false

func _handle_laser_and_shooting(delta: float) -> void:
	if _check_los():
		var progress = clamp(time_in_sight / windup_delay, 0.2, 1.0)
		var col      = COLOR_WINDUP.lerp(COLOR_ATTACK, progress)
		_set_laser_color(col, 20.0 * progress)

		if can_shoot and state == State.ATTACK and time_in_sight >= windup_delay:
			shoot()
	else:
		_reset_combat_spool()
		_set_laser_color(COLOR_WINDUP, 5.0)
		current_target_offset = current_target_offset.lerp(Vector3.ZERO, delta)

func _update_laser_visuals() -> void:
	if not laser_mesh.visible:
		return
		
	# FIX: The ray's global_basis is already rotated to point at the offset in _aim_at_position.
	# We just need to shoot it straight down its own local Z axis so it doesn't double-offset!
	ray.target_position = Vector3(0, 0, -detection_range)
	ray.force_raycast_update()
	
	if ray.is_colliding():
		var hit_dist = ray.global_position.distance_to(ray.get_collision_point())
		_set_laser_length(hit_dist)
	else:
		_set_laser_length(detection_range)

func _reset_combat_spool() -> void:
	time_in_sight     = 0.0
	current_fire_rate = min_fire_rate

func _set_laser_length(length: float) -> void:
	if laser_mesh.mesh:
		laser_mesh.mesh.height  = length
		laser_mesh.position.z   = -length / 2.0

func _set_laser_visible(vis: bool) -> void:
	laser_mesh.visible = vis

func _set_laser_color(color: Color, energy: float) -> void:
	var mat = laser_mesh.get_active_material(0)
	if mat:
		mat.albedo_color               = color
		mat.emission_energy_multiplier = energy

# ---------------------------------------------------------------------------
#  SHOOTING
# ---------------------------------------------------------------------------

func shoot() -> void:
	can_shoot = false
	_pick_random_aim_spot()

	if muzzle_flash: muzzle_flash.restart()
	if shoot_sound:
		shoot_sound.pitch_scale = randf_range(0.9, 1.1)
		shoot_sound.play()
	if flash_light:
		flash_light.visible = true
		get_tree().create_timer(0.05).timeout.connect(
			func(): if is_instance_valid(flash_light): flash_light.visible = false
		)

	# --- FIX: USE PHYSICS SERVER INSTEAD OF THE VISUAL RAYCAST ---
	var space_state = get_world_3d().direct_space_state
	var target_node = player.get_node_or_null("TargetPoint")
	var base_aim = target_node.global_position if target_node else player.global_position + Vector3(0, 1.2, 0)
	var final_aim = base_aim + current_target_offset
	
	var origin = ray.global_position if is_instance_valid(ray) else global_position
	var query = PhysicsRayQueryParameters3D.create(origin, final_aim)
	query.exclude = [self]
	query.collision_mask = ray.collision_mask # Respects the layers set in the editor
	
	var result = space_state.intersect_ray(query)
	if result and is_instance_valid(result.collider):
		if result.collider.has_method("take_damage"):
			result.collider.take_damage(damage)
	# -------------------------------------------------------------

	await get_tree().create_timer(current_fire_rate).timeout
	can_shoot = true

	current_fire_rate = max(current_fire_rate - fire_rate_accel, max_fire_rate)
	current_target_offset = Vector3.ZERO

func _pick_random_aim_spot() -> void:
	current_target_offset = Vector3(
		randf_range(-0.3, 0.3),
		randf_range(-0.5, 0.5),
		0.0
	)

# ---------------------------------------------------------------------------
#  DAMAGE & DEATH
# ---------------------------------------------------------------------------

func take_damage(amount: float) -> void:
	if state == State.DEAD:
		return
	health -= amount
	if health <= 0.0:
		die()
		return

	if player != null and dodge_timer <= 0.0:
		dodge_timer     = 0.4
		var to_player   = (player.global_position - global_position).normalized()
		var right       = to_player.cross(Vector3.UP).normalized()
		dodge_direction = (right if randf() > 0.5 else -right)
		dodge_direction.y = 0.5
		dodge_direction   = dodge_direction.normalized()

func die() -> void:
	state     = State.DEAD
	can_shoot = false
	laser_mesh.visible = false
	explode_audio.play()

	set_collision_layer_value(2, false)
	set_collision_mask_value(2, false)
	remove_from_group("drones")

	var remaining = get_tree().get_nodes_in_group("drones").size()
	if SaveManager:
		if remaining > 0:
			SaveManager.update_objective_text(
				"fight_security",
				"Fight through Asterisk Security (" + str(remaining) + " left)"
			)
		else:
			SaveManager.complete_objective("fight_security")

	velocity = Vector3(randf_range(-4, 4), 6.0, randf_range(-4, 4))
	await get_tree().create_timer(5.0).timeout
	queue_free()

func _process_dead(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
		$DroneModel.rotate_x(8.0 * delta)
		$DroneModel.rotate_z(5.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	move_and_slide()
