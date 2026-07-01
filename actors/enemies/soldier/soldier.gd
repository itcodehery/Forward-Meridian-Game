extends CharacterBody3D
class_name SoldierAI

enum State { IDLE, PATROL, COMBAT, FLANK }
enum Role { NONE, SUPPRESSOR, FLANKER }

@export var max_health: float = 100.0
@export var speed: float = 3.5
@export var patrol_speed: float = 1.5
@export var sight_range: float = 40.0
@export var attack_range: float = 20.0
@export var squad_id: String = "alpha"

@onready var nav_agent = $NavigationAgent3D
@onready var vision_ray = $VisionRay
@onready var anim_tree = $AnimationTree

var health: float
var is_dead: bool = false
var current_state: State = State.IDLE
var current_role: Role = Role.NONE
var target: Node3D = null

var squad_manager = null

func _ready():
	health = max_health
	add_to_group("enemies")
	
	vision_ray.add_exception(self)
	
	var managers = get_tree().get_nodes_in_group("squad_managers")
	if managers.size() > 0:
		squad_manager = managers[0]
		squad_manager.register_soldier(self, squad_id)

func _physics_process(delta):
	if is_dead: return
	
	_handle_vision()
	
	match current_state:
		State.IDLE:
			_update_animations(Vector3.ZERO, false)
		State.PATROL:
			_process_movement(delta, patrol_speed)
		State.COMBAT:
			_process_combat(delta)
		State.FLANK:
			_process_movement(delta, speed)

func _handle_vision():
	if current_state == State.COMBAT or current_state == State.FLANK:
		return 
		
	var player = get_tree().get_first_node_in_group("players")
	if player:
		var dir_to_player = global_position.direction_to(player.global_position)
		var dist = global_position.distance_to(player.global_position)
		
		# Simple 180 degree FOV check
		if dist <= sight_range and -global_transform.basis.z.dot(dir_to_player) > 0.0:
			vision_ray.target_position = to_local(player.global_position + Vector3(0, 1, 0))
			vision_ray.force_raycast_update()
			if vision_ray.is_colliding() and vision_ray.get_collider() == player:
				if squad_manager:
					squad_manager.report_combat(squad_id, player)
				else:
					assign_role(Role.SUPPRESSOR, player)

func assign_role(role: Role, t: Node3D):
	current_role = role
	target = t
	if role == Role.FLANKER:
		current_state = State.FLANK
		_calculate_flank_position()
	else:
		current_state = State.COMBAT

func _process_combat(delta):
	if not is_instance_valid(target):
		current_state = State.IDLE
		return
		
	look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP, true)
	
	var dist = global_position.distance_to(target.global_position)
	if dist > attack_range:
		nav_agent.target_position = target.global_position
		_process_movement(delta, speed)
	else:
		_update_animations(Vector3.ZERO, true)

func _calculate_flank_position():
	if not is_instance_valid(target): return
	var to_us = target.global_position.direction_to(global_position)
	var right = to_us.cross(Vector3.UP).normalized()
	if randf() > 0.5: right = -right
	
	nav_agent.target_position = target.global_position + (right * 10.0)

func _process_movement(delta, move_speed):
	if nav_agent.is_navigation_finished():
		if current_state == State.FLANK:
			current_state = State.COMBAT
		else:
			_update_animations(Vector3.ZERO, false)
		return
		
	var next_pos = nav_agent.get_next_path_position()
	var dir = global_position.direction_to(next_pos)
	dir.y = 0
	dir = dir.normalized()
	
	velocity = dir * move_speed
	if not is_on_floor():
		velocity.y -= 9.8 * delta
		
	if dir.length_squared() > 0.01:
		look_at(global_position + dir, Vector3.UP, true)
		
	move_and_slide()
	_update_animations(velocity, false)

func _update_animations(vel: Vector3, is_shooting: bool):
	if not anim_tree: return
	var moving = vel.length() > 0.1
	anim_tree.set("parameters/conditions/is_idle", not moving and not is_shooting)
	anim_tree.set("parameters/conditions/is_walking", moving)
	anim_tree.set("parameters/conditions/is_shooting", is_shooting)

func take_damage(amount: float):
	if is_dead: return
	health -= amount
	if health <= 0:
		die()

func die():
	is_dead = true
	if squad_manager:
		squad_manager.unregister_soldier(self, squad_id)
	if anim_tree:
		anim_tree.set("parameters/conditions/is_dead", true)
		anim_tree.set("parameters/conditions/is_idle", false)
		anim_tree.set("parameters/conditions/is_walking", false)
		anim_tree.set("parameters/conditions/is_shooting", false)
	
	$CollisionShape3D.set_deferred("disabled", true)
