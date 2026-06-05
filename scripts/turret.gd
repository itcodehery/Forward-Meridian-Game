extends StaticBody3D

# =============================================================================
#  TURRET AI - AAA BEHAVIOUR REWRITE (Split Axis)
#  States: idle → tracking → windup → firing → lost → cooldown
# =============================================================================

# ---------------------------------------------------------------------------
#  EXPORTS
# ---------------------------------------------------------------------------
@export_group("Combat Stats")
@export var health: float         = 250.0
@export var damage: float         = 4.0

@export_group("Fire Rate / Windup")
@export var windup_duration: float  = 1.2    # Seconds before first shot
@export var min_fire_rate: float    = 0.4    # Slow starting cadence
@export var max_fire_rate: float    = 0.08   # Max cadence after spooling
@export var fire_rate_accel: float  = 0.05   # Speedup per shot

@export_group("Overheat")
@export var shots_before_overheat: int   = 12    # Shots until forced cooldown
@export var cooldown_duration: float     = 3.5   # Seconds of forced silence
@export var overheat_bark: String        = ""    # Optional subtitle on overheat

@export_group("AI Ranges")
@export var turret_range: float      = 20.0
@export var fov_degrees: float       = 140.0  # Total horizontal FOV

@export_group("Scan Behaviour")
@export var scan_speed: float        = 0.6    # Radians/sec of idle sweep
@export var scan_arc: float          = 1.1    # Half-arc in radians (~63 deg each side)
@export var lost_hold_time: float    = 1.2    # Seconds turret holds on last pos before giving up

@export_group("Narrative")
@export var unit_name: String        = ""
@export var detection_message: String = "Target acquired."

# ---------------------------------------------------------------------------
#  NODE REFERENCES (UPDATED FOR SPLIT AXIS)
# ---------------------------------------------------------------------------
@onready var holder_pivot = $HolderPivot
@onready var head_pivot   = $HolderPivot/HeadPivot
@onready var ray          = $HolderPivot/HeadPivot/RayCast3D
@onready var laser_mesh   = $HolderPivot/HeadPivot/RayCast3D/MeshInstance3D
@onready var muzzle_flash = $HolderPivot/HeadPivot/Muzzle/MuzzleFlash
@onready var shoot_sound  = $HolderPivot/HeadPivot/Muzzle/ShootSound
@onready var flash_light  = $HolderPivot/HeadPivot/Muzzle/OmniLight3D
@onready var head_mesh = $HolderPivot/HeadPivot/Head
@onready var holders_mesh = $HolderPivot/Holders

@export_group("Audio")
@export var explosion_sound: AudioStream

# ---------------------------------------------------------------------------
#  LASER COLOUR PALETTE
# ---------------------------------------------------------------------------
const COLOR_IDLE      = Color(0.2, 0.5, 1.0, 0.12)
const COLOR_TRACKING  = Color(1.0, 0.75, 0.0, 0.65)
const COLOR_WINDUP    = Color(1.0, 0.15, 0.0, 0.5)
const COLOR_FIRING    = Color(1.0, 0.0,  0.0, 1.0)
const COLOR_LOST      = Color(1.0, 0.4,  0.0, 0.45)
const COLOR_OVERHEAT  = Color(1.0, 1.0,  1.0, 1.0)

# ---------------------------------------------------------------------------
#  STATE MACHINE
# ---------------------------------------------------------------------------
enum State {
	IDLE,
	TRACKING,
	WINDUP,
	FIRING,
	LOST,
	COOLDOWN,
	DEAD
}

var state: State = State.IDLE

# ---------------------------------------------------------------------------
#  RUNTIME VARS
# ---------------------------------------------------------------------------
var player: Node3D         = null
var can_shoot: bool        = true
var has_detected: bool     = false

# Firing
var current_fire_rate: float      = 0.4
var current_target_offset: Vector3 = Vector3.ZERO
var shots_fired: int              = 0

# Windup
var windup_timer: float    = 0.0

# Lost
var lost_timer: float      = 0.0
var last_known_pos: Vector3 = Vector3.ZERO

# Cooldown
var cooldown_timer: float  = 0.0

# Scan
var scan_angle: float      = 0.0   
var scan_dir: float        = 1.0   

# Base rest rotations for both pivots
var holder_rest_basis: Basis
var head_rest_basis: Basis

# ---------------------------------------------------------------------------
#  READY
# ---------------------------------------------------------------------------
func _ready() -> void:
	add_to_group("turrets")
	player = get_tree().get_first_node_in_group("players")
	ray.target_position.z = -turret_range
	
	# Store neutral resting positions
	holder_rest_basis = holder_pivot.global_basis  
	head_rest_basis = head_pivot.basis
	
	laser_mesh.visible = false

# ---------------------------------------------------------------------------
#  PROCESS 
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if state == State.DEAD:
		return

	if player == null:
		player = get_tree().get_first_node_in_group("players")
		if player == null:
			_set_laser(false)
			return

	# Distance/LOS calculations are now based on the head_pivot (where the eyes/barrels are)
	var dist: float    = head_pivot.global_position.distance_to(player.global_position)
	var in_range: bool = dist < turret_range
	var has_los: bool  = in_range and _check_los()
	var in_fov: bool   = in_range and _check_fov()

	match state:
		State.IDLE:      _state_idle(delta, has_los, in_fov)
		State.TRACKING:  _state_tracking(delta, has_los, in_fov)
		State.WINDUP:    _state_windup(delta, has_los)
		State.FIRING:    _state_firing(delta, has_los)
		State.LOST:      _state_lost(delta, has_los, in_fov)
		State.COOLDOWN:  _state_cooldown(delta, has_los, in_fov)
		
	_update_laser_visuals()

# ---------------------------------------------------------------------------
#  STATES
# ---------------------------------------------------------------------------

func _state_idle(delta: float, has_los: bool, in_fov: bool) -> void:
	_do_scan_sweep(delta)
	_set_laser(true)
	_set_laser_color(COLOR_IDLE, 3.0)

	if has_los and in_fov:
		_enter_tracking()

func _state_tracking(delta: float, has_los: bool, in_fov: bool) -> void:
	if not has_los or not in_fov:
		_enter_lost()
		return

	_aim_at_player(delta, 8.0)
	last_known_pos = player.global_position

	var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	_set_laser_color(COLOR_TRACKING, 10.0 + 8.0 * pulse)

	windup_timer += delta
	if windup_timer >= 0.3:
		_enter_windup()

func _state_windup(delta: float, has_los: bool) -> void:
	if not has_los:
		_enter_lost()
		return

	_aim_at_player(delta, 10.0)
	last_known_pos = player.global_position
	windup_timer  += delta

	var progress = clamp(windup_timer / windup_duration, 0.0, 1.0)
	var windup_color = COLOR_WINDUP.lerp(COLOR_FIRING, progress)
	_set_laser_color(windup_color, 10.0 + 25.0 * progress)

	if progress > 0.8:
		var flicker = abs(sin(Time.get_ticks_msec() * 0.02))
		_set_laser_color(COLOR_FIRING, 20.0 + 20.0 * flicker)

	if windup_timer >= windup_duration:
		_enter_firing()

func _state_firing(delta: float, has_los: bool) -> void:
	if not has_los:
		_enter_lost()
		return

	_aim_at_player(delta, 12.0)
	last_known_pos = player.global_position

	_set_laser_color(COLOR_FIRING, 30.0)

	if can_shoot:
		shoot()

func _state_lost(delta: float, has_los: bool, in_fov: bool) -> void:
	lost_timer -= delta
	_set_laser(true)

	_set_laser_color(COLOR_LOST, 8.0)
	_aim_at_position(last_known_pos, delta, 4.0)

	if has_los and in_fov:
		_enter_windup()
		return

	if lost_timer <= 0.0:
		_enter_idle()

func _state_cooldown(delta: float, has_los: bool, in_fov: bool) -> void:
	cooldown_timer -= delta
	can_shoot = false

	var cool_progress = clamp(1.0 - (cooldown_timer / cooldown_duration), 0.0, 1.0)
	var cool_color    = COLOR_OVERHEAT.lerp(COLOR_IDLE, cool_progress)
	_set_laser_color(cool_color, 40.0 * (1.0 - cool_progress) + 2.0)

	if cooldown_timer <= 0.0:
		can_shoot  = true
		shots_fired = 0
		if has_los and in_fov:
			_enter_windup()   
		else:
			_enter_idle()

# ---------------------------------------------------------------------------
#  STATE TRANSITIONS
# ---------------------------------------------------------------------------

func _enter_tracking() -> void:
	state        = State.TRACKING
	windup_timer = 0.0
	if not has_detected:
		has_detected = true
		# if SubtitleManager and unit_name != "":
		#     SubtitleManager.show_subtitle(unit_name, detection_message, 3.0)

func _enter_windup() -> void:
	state        = State.WINDUP
	windup_timer = 0.0

func _enter_firing() -> void:
	state             = State.FIRING
	current_fire_rate = min_fire_rate
	shots_fired       = 0

func _enter_lost() -> void:
	state      = State.LOST
	lost_timer = lost_hold_time
	_reset_spool()

func _enter_idle() -> void:
	state      = State.IDLE
	scan_angle = 0.0
	_reset_spool()
	_set_laser_color(COLOR_IDLE, 3.0)

func _enter_cooldown() -> void:
	state          = State.COOLDOWN
	cooldown_timer = cooldown_duration
	can_shoot      = false
	# if overheat_bark != "" and SubtitleManager:
	#     SubtitleManager.show_subtitle(unit_name, overheat_bark, 2.0)

# ---------------------------------------------------------------------------
#  AIMING (SPLIT AXIS REWRITE)
# ---------------------------------------------------------------------------

func _aim_at_player(delta: float, speed: float) -> void:
	var target_node = player.get_node_or_null("TargetPoint")
	var aim_pos     = target_node.global_position if target_node else player.global_position + Vector3(0, 1.2, 0)
	_aim_at_position(aim_pos, delta, speed)

func _aim_at_position(pos: Vector3, delta: float, speed: float) -> void:
	# 1. HORIZONTAL ROTATION (Holder Pivot)
	# Target position mapped to the same height as the holder so it only turns Y
	var flat_pos = Vector3(pos.x, holder_pivot.global_position.y, pos.z)
	var holder_up_dir = holder_rest_basis.y 
	
	if holder_pivot.global_position.distance_to(flat_pos) > 0.01:
		var target_holder_xform = holder_pivot.global_transform.looking_at(flat_pos, holder_up_dir)
		holder_pivot.global_basis = holder_pivot.global_basis.slerp(target_holder_xform.basis, speed * delta).orthonormalized()

	# 2. VERTICAL ROTATION (Head Pivot)
	# Head tilts X to look at the true 3D target. We use the Holder's Y as the 'up' direction 
	# to prevent the head from rolling/twisting sideways.
	if head_pivot.global_position.distance_to(pos) > 0.01:
		var head_up_dir = holder_pivot.global_basis.y
		# Optional safeguard to prevent breaking if target is exactly above/below turret
		var dir_to_target = (pos - head_pivot.global_position).normalized()
		if abs(dir_to_target.dot(head_up_dir)) < 0.999:
			var target_head_xform = head_pivot.global_transform.looking_at(pos, head_up_dir)
			head_pivot.global_basis = head_pivot.global_basis.slerp(target_head_xform.basis, speed * delta).orthonormalized()

# ---------------------------------------------------------------------------
#  PASSIVE SCAN SWEEP (SPLIT AXIS)
# ---------------------------------------------------------------------------

func _do_scan_sweep(delta: float) -> void:
	scan_angle += scan_speed * scan_dir * delta

	if abs(scan_angle) >= scan_arc:
		scan_dir   = -scan_dir
		scan_angle  = clamp(scan_angle, -scan_arc, scan_arc)

	# 1. Sweep the holder left/right
	var sweep_basis = holder_rest_basis.rotated(holder_rest_basis.y, scan_angle)
	# Slerp so snapping out of 'LOST' state back to 'IDLE' is smooth
	holder_pivot.global_basis = holder_pivot.global_basis.slerp(sweep_basis, 4.0 * delta).orthonormalized()
	
	# 2. Reset the head tilt back to neutral while sweeping
	head_pivot.basis = head_pivot.basis.slerp(head_rest_basis, 4.0 * delta).orthonormalized()
	
	ray.target_position = Vector3(0, 0, -turret_range) # Center the ray

# ---------------------------------------------------------------------------
#  LOS + FOV REWRITE
# ---------------------------------------------------------------------------

func _check_los() -> bool:
	var target_node = player.get_node_or_null("TargetPoint")
	var target_pos = target_node.global_position if target_node else player.global_position + Vector3(0, 1.2, 0)
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(head_pivot.global_position, target_pos)
	# Ignore the root static body AND both pivots to prevent self-intersection
	query.exclude = [self, holder_pivot, head_pivot]
	
	var result = space_state.intersect_ray(query)
	if result and is_instance_valid(result.collider):
		return result.collider == player or result.collider.is_in_group("players")
		
	return false

func _check_fov() -> bool:
	var to_player = (player.global_position - head_pivot.global_position).normalized()
	var forward = -head_pivot.global_basis.z.normalized()
	var angle = rad_to_deg(to_player.angle_to(forward))
	return angle < fov_degrees * 0.5

# ---------------------------------------------------------------------------
#  SHOOTING
# ---------------------------------------------------------------------------

func shoot() -> void:
	can_shoot = false
	_pick_random_aim_spot()

	ray.target_position = Vector3(current_target_offset.x, current_target_offset.y, -turret_range)
	ray.force_raycast_update()

	if muzzle_flash:
		muzzle_flash.restart()
		muzzle_flash.emitting = true
	if flash_light:
		flash_light.visible = true
		get_tree().create_timer(0.05).timeout.connect(
			func(): if is_instance_valid(flash_light): flash_light.visible = false
		)
	if shoot_sound:
		shoot_sound.pitch_scale = randf_range(0.9, 1.1)
		shoot_sound.play()

	if ray.is_colliding():
		var target = ray.get_collider()
		if is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(damage)

	shots_fired += 1

	await get_tree().create_timer(current_fire_rate).timeout

	if shots_fired >= shots_before_overheat:
		_enter_cooldown()
		return

	can_shoot = true
	current_fire_rate = max(current_fire_rate - fire_rate_accel, max_fire_rate)

func _pick_random_aim_spot() -> void:
	current_target_offset = Vector3(
		randf_range(-0.5, 0.5),
		randf_range(-0.5, 0.5),
		0.0
	)

func _reset_spool() -> void:
	current_fire_rate     = min_fire_rate
	current_target_offset = Vector3.ZERO
	ray.target_position   = Vector3(0, 0, -turret_range)

# ---------------------------------------------------------------------------
#  LASER HELPERS
# ---------------------------------------------------------------------------

func _set_laser(vis: bool) -> void:
	laser_mesh.visible = vis

func _set_laser_color(color: Color, energy: float) -> void:
	var mat = laser_mesh.get_active_material(0)
	if mat:
		mat.albedo_color               = color
		mat.emission_energy_multiplier = energy

func _set_laser_length(length: float) -> void:
	if laser_mesh.mesh:
		laser_mesh.mesh.height = length
		laser_mesh.position.z  = -length / 2.0

func _update_laser_visuals() -> void:
	if not laser_mesh.visible:
		return
		
	var old_target = ray.target_position
	ray.target_position = Vector3(0, 0, -turret_range)
	ray.force_raycast_update()
	
	if ray.is_colliding():
		var hit_dist = head_pivot.global_position.distance_to(ray.get_collision_point())
		_set_laser_length(hit_dist)
	else:
		_set_laser_length(turret_range)
		
	ray.target_position = old_target

# ---------------------------------------------------------------------------
#  DAMAGE & DEATH
# ---------------------------------------------------------------------------

func take_damage(amount: float) -> void:
	if state == State.DEAD:
		return
	health -= amount
	if health <= 0.0:
		explode()

func _turn_into_debris(mesh_node: MeshInstance3D, impulse: Vector3) -> void:
	if not is_instance_valid(mesh_node): return
	
	# 1. Create the physics body and collision shape
	var rb = RigidBody3D.new()
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	
	# Automatically size the collision box based on the size of your Blender mesh!
	if mesh_node.mesh:
		shape.size = mesh_node.mesh.get_aabb().size
		
	col.shape = shape
	rb.add_child(col)
	
	# Make sure it collides with the floor (Assuming your floor is on Layer 1)
	rb.collision_layer = 1
	rb.collision_mask = 1 
	
	# 2. Save the mesh's current position and rotation in the world
	var saved_global_transform = mesh_node.global_transform
	
	# 3. Detach the mesh from the turret and attach it to our new RigidBody
	mesh_node.get_parent().remove_child(mesh_node)
	rb.add_child(mesh_node)
	
	# Center the mesh perfectly inside the collision box
	mesh_node.transform = Transform3D.IDENTITY
	
	# 4. Add the new RigidBody to the world so it isn't deleted with the turret
	get_tree().current_scene.add_child(rb)
	
	# 5. Snap the RigidBody to where the mesh originally was, and apply the pop force
	rb.global_transform = saved_global_transform
	rb.apply_impulse(impulse, Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5), 0))
	
	# Optional cleanup: Delete the debris after 10 seconds so it doesn't clutter the map
	get_tree().create_timer(10.0).timeout.connect(rb.queue_free)

func explode() -> void:
	state = State.DEAD
	_set_laser(false)
	
	# Optional: Turn off collisions on the main base so the player can walk through the ruins
	if self is StaticBody3D:
		self.collision_layer = 0
		self.collision_mask = 0

	# 1. Pop the head straight up with a slight random spin
	var head_pop_dir = Vector3(randf_range(-1.5, 1.5), 7.0, randf_range(-1.5, 1.5))
	_turn_into_debris(head_mesh, head_pop_dir)
	
	# --- PLAY EXPLOSION SOUND ---
	if explosion_sound:
		var audio_player = AudioStreamPlayer3D.new()
		audio_player.stream = explosion_sound
		audio_player.unit_size = 5.0 
		audio_player.max_db = 3.0
		get_tree().current_scene.add_child(audio_player)
		audio_player.global_position = self.global_position
		audio_player.play()
		audio_player.finished.connect(audio_player.queue_free)
	
	var all_turrets = get_tree().get_nodes_in_group("turrets")
	var remaining   = max(all_turrets.size() - 1, 0)

	if SaveManager:
		if remaining > 0:
			SaveManager.update_objective_text("kill_turrets", "Destroy turrets (" + str(remaining) + " left)")
		else:
			SaveManager.complete_objective("kill_turrets")

	# Delete the main turret logic. 
	# The holders disappear with it, but the head survives as debris!
	queue_free()
