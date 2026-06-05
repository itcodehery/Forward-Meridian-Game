extends CharacterBody3D

# =============================================================================
#  SCOUT DRONE  —  "It will not stop moving."
#
#  A ranged harassment enemy. Never gets close. Never stops moving.
#  Strafe-orbits the player at medium range and fires projectile bursts.
#  Close in and it boosts backwards. Stand still and it circles tighter.
#
#  STATES:
#    ORBIT      → Strafing a circle around the player, shooting in bursts.
#    REPOSITION → Player got too close — reversing thrust to regain safe range.
#    RELOAD     → Brief cooldown after a burst, still moving but not shooting.
# =============================================================================

@export_group("Combat Stats")
@export var health: float = 30.0
@export var damage: float = 5.0
@export var attack_cooldown: float = 0.28        # Delay between individual shots in a burst
@export var burst_size: int = 3                  # Shots per burst
@export var burst_cooldown: float = 2.2          # Pause between bursts

@export_group("Movement")
@export var orbit_speed: float = 6.0             # Lateral strafe speed while orbiting
@export var preferred_range: float = 12.0        # Ideal distance from player
@export var too_close_range: float = 6.0         # Triggers REPOSITION
@export var reposition_speed: float = 14.0       # Reverse thrust speed
@export var hover_height: float = 2.2            # Target height above the navmesh floor
@export var hover_bob_amplitude: float = 0.15
@export var hover_bob_frequency: float = 1.6
@export var acceleration: float = 7.0

@export_group("Projectile")
@export var projectile_scene: PackedScene        # Assign your bullet/laser scene in the editor
@export var muzzle_offset: Vector3 = Vector3(0, 0, -1.0)  # Local-space spawn point

@onready var nav_agent = $NavigationAgent3D
@onready var mesh = $swarmer/Cube
@onready var attack_box = $AttackBox            # Emergency zap if the drone is physically rammed

var player: Node3D = null
var is_dead: bool = false

enum State { ORBIT, REPOSITION, RELOAD }
var state: State = State.ORBIT

var orbit_angle: float = 0.0
var orbit_direction: float = 1.0    # +1 or -1, flipped occasionally for unpredictability
var time_alive: float = 0.0

var shots_fired_this_burst: int = 0
var time_since_shot: float = 0.0
var time_since_burst: float = 0.0
var time_in_reposition: float = 0.0
var direction_flip_timer: float = 0.0

func _ready() -> void:
	add_to_group("swarmers")
	player = get_tree().get_first_node_in_group("players")
	orbit_angle = randf() * TAU
	orbit_direction = 1.0 if randf() > 0.5 else -1.0
	direction_flip_timer = randf_range(3.0, 7.0)

	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 1.5

func _physics_process(delta: float) -> void:
	if is_dead:
		_process_dead(delta)
		return

	time_alive += delta
	time_since_shot += delta
	time_since_burst += delta
	direction_flip_timer -= delta

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("players")
		if not is_instance_valid(player):
			return

	# Flip orbit direction occasionally
	if direction_flip_timer <= 0.0:
		orbit_direction *= -1.0
		direction_flip_timer = randf_range(3.0, 8.0)

	var dist_to_player: float = global_position.distance_to(player.global_position)

	# --- STATE TRANSITIONS ---
	match state:
		State.ORBIT:
			if dist_to_player < too_close_range:
				state = State.REPOSITION
				time_in_reposition = 0.0
		State.REPOSITION:
			time_in_reposition += delta
			if dist_to_player >= preferred_range or time_in_reposition > 2.5:
				state = State.ORBIT
		State.RELOAD:
			if time_since_burst >= burst_cooldown:
				shots_fired_this_burst = 0
				state = State.ORBIT

	# --- MOVEMENT ---
	var move_velocity := Vector3.ZERO

	match state:
		State.ORBIT:
			move_velocity = _calculate_orbit_velocity(delta, dist_to_player)
		State.REPOSITION:
			var away_dir = global_position.direction_to(player.global_position) * -1.0
			away_dir.y = 0.0
			if away_dir.length_squared() > 0.001:
				away_dir = away_dir.normalized()
			move_velocity = away_dir * reposition_speed
		State.RELOAD:
			move_velocity = _calculate_orbit_velocity(delta, dist_to_player) * 0.4

	# Hover: push toward target height using a downward raycast for floor detection
	var target_y = _get_floor_height() + hover_height
	var bob = sin(time_alive * hover_bob_frequency) * hover_bob_amplitude
	move_velocity.y = (target_y + bob - global_position.y) * 5.0

	velocity = velocity.lerp(move_velocity, acceleration * delta)
	move_and_slide()

	# --- ROTATION: always face the player, level ---
	var look_target = player.global_position
	look_target.y = global_position.y
	var dir_to_player = global_position.direction_to(look_target)
	if dir_to_player.length_squared() > 0.01 and abs(dir_to_player.dot(Vector3.UP)) < 0.99:
		var target_basis = Basis.looking_at(dir_to_player, Vector3.UP)
		mesh.global_basis = mesh.global_basis.slerp(target_basis, 10.0 * delta)

	# --- SHOOTING ---
	if state == State.ORBIT or state == State.REPOSITION:
		_handle_shooting()

# Keeps the drone on a circle around the player and nudges it to preferred_range.
func _calculate_orbit_velocity(delta: float, dist_to_player: float) -> Vector3:
	orbit_angle += orbit_direction * (orbit_speed / max(dist_to_player, 1.0)) * delta

	var orbit_target = player.global_position + Vector3(
		cos(orbit_angle) * preferred_range,
		0.0,
		sin(orbit_angle) * preferred_range
	)

	var steer_dir = global_position.direction_to(orbit_target)
	steer_dir.y = 0.0
	if steer_dir.length_squared() > 0.001:
		steer_dir = steer_dir.normalized()

	return steer_dir * orbit_speed

func _handle_shooting() -> void:
	if state == State.RELOAD:
		return

	# Line-of-sight check before firing
	var space = get_world_3d().direct_space_state
	var ray_origin = global_position
	var ray_target = player.global_position + Vector3(0, 1.0, 0)
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_target, 0xFFFFFFFF, [self])
	var result = space.intersect_ray(query)

	if result and result.collider != player:
		return  # Something's in the way

	if shots_fired_this_burst < burst_size:
		if time_since_shot >= attack_cooldown:
			_fire_shot()
			shots_fired_this_burst += 1
			time_since_shot = 0.0
	else:
		state = State.RELOAD
		time_since_burst = 0.0

func _fire_shot() -> void:
	if not is_instance_valid(player):
		return

	if projectile_scene == null:
		# --- FALLBACK: instant-hit raycast if no bullet scene is assigned ---
		var space = get_world_3d().direct_space_state
		var ray_origin = global_position
		var ray_target = player.global_position + Vector3(0, 1.0, 0)
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_target, 0xFFFFFFFF, [self])
		var result = space.intersect_ray(query)
		if result and result.collider == player:
			if player.has_method("take_damage"):
				player.take_damage(damage)
		return

	# Spawn projectile at muzzle position, aimed at the player's chest
	var bullet = projectile_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	var muzzle_pos = global_position + mesh.global_basis * muzzle_offset
	bullet.global_position = muzzle_pos

	var aim_target = player.global_position + Vector3(0, 1.0, 0)
	var shot_dir = muzzle_pos.direction_to(aim_target)

	# Expects the projectile to expose a launch(direction: Vector3) method
	if bullet.has_method("launch"):
		bullet.launch(shot_dir)

func _get_floor_height() -> float:
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + Vector3.DOWN * 20.0,
		0xFFFFFFFF,
		[self]
	)
	var result = space.intersect_ray(query)
	if result:
		return result.position.y
	return 0.0

# Called when the player physically walks into the drone (AttackBox)
func _on_attack_box_body_entered(body: Node3D) -> void:
	if is_dead:
		return
	if body == player:
		if body.has_method("take_damage"):
			body.take_damage(damage)
		# Knocked back from the collision
		var push = (global_position - player.global_position).normalized()
		velocity = push * reposition_speed
		state = State.REPOSITION
		time_in_reposition = 0.0

func take_damage(amount: float) -> void:
	if is_dead:
		return
	health -= amount
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	remove_from_group("swarmers")
	$CollisionShape3D.set_deferred("disabled", true)
	attack_box.set_deferred("monitoring", false)
	velocity = Vector3(randf_range(-4, 4), randf_range(1, 5), randf_range(-4, 4))
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _process_dead(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
		mesh.rotate_x(8.0 * delta)
		mesh.rotate_z(5.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	move_and_slide()
