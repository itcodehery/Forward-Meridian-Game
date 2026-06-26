extends Control

@export var max_range: float = 30.0
@export var radar_radius: float = 80.0

@onready var objective_arrow = $ObjectiveArrow
@onready var enemy_container = $EnemyContainer
@onready var player_indicator = $PlayerIndicator

var _cached_objective: Node3D = null
var _enemy_blips: Dictionary = {}

func _ready():
	custom_minimum_size = Vector2(radar_radius * 2, radar_radius * 2)

func _process(_delta):
	_update_radar()

func _update_radar():
	var center = Vector2(radar_radius, radar_radius)
	var player = get_tree().get_first_node_in_group("players")
	
	if not player:
		# Hide everything if no player
		enemy_container.hide()
		objective_arrow.hide()
		return
		
	enemy_container.show()
	
	# --- Update Enemies ---
	var enemies = get_tree().get_nodes_in_group("enemies")
	var active_enemy_ids = []
	
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		if enemy.has_method("is_dead") and enemy.is_dead(): continue
		if "health" in enemy and enemy.health <= 0: continue
		
		var enemy_id = enemy.get_instance_id()
		active_enemy_ids.append(enemy_id)
		
		var local_pos = player.to_local(enemy.global_position)
		var map_pos = Vector2(local_pos.x, local_pos.z)
		var distance = map_pos.length()
		
		if distance <= max_range:
			# Get or create blip
			var blip: Control
			if _enemy_blips.has(enemy_id):
				blip = _enemy_blips[enemy_id]
			else:
				blip = _create_enemy_blip()
				_enemy_blips[enemy_id] = blip
				
			blip.show()
			var mapped_dist = (distance / max_range) * radar_radius
			var angle = map_pos.angle()
			var dot_offset = Vector2(cos(angle), sin(angle)) * mapped_dist
			# Center the blip on the position
			blip.position = center + dot_offset - (blip.size / 2.0)
		else:
			if _enemy_blips.has(enemy_id):
				_enemy_blips[enemy_id].hide()
				
	# Cleanup dead/removed enemies
	var ids_to_remove = []
	for id in _enemy_blips.keys():
		if not id in active_enemy_ids:
			_enemy_blips[id].queue_free()
			ids_to_remove.append(id)
	for id in ids_to_remove:
		_enemy_blips.erase(id)

	# --- Update Objective ---
	_update_cached_objective()
	if is_instance_valid(_cached_objective):
		objective_arrow.show()
		var obj_local = player.to_local(_cached_objective.global_position)
		var obj_map = Vector2(obj_local.x, obj_local.z)
		var angle = obj_map.angle()
		
		var arrow_dist = radar_radius + 15.0 # Just outside
		var arrow_center = center + Vector2(cos(angle), sin(angle)) * arrow_dist
		
		objective_arrow.position = arrow_center
		# Add PI/2 because UI rotation 0 points UP, but angle 0 is RIGHT.
		# Actually, rotation in Godot 2D: 0 is right, PI/2 is down.
		objective_arrow.rotation = angle + PI/2 
	else:
		objective_arrow.hide()

func _create_enemy_blip() -> Control:
	var blip = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color.RED
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	blip.add_theme_stylebox_override("panel", style)
	blip.custom_minimum_size = Vector2(8, 8)
	blip.size = Vector2(8, 8)
	enemy_container.add_child(blip)
	return blip

func _update_cached_objective():
	if is_instance_valid(_cached_objective) and "objective_id" in _cached_objective:
		if SaveManager.game_data.objectives.has(_cached_objective.objective_id) and not SaveManager.game_data.objectives[_cached_objective.objective_id].done:
			return 
			
	_cached_objective = null
	var waypoints = get_tree().get_nodes_in_group("objective_waypoints")
	for wp in waypoints:
		if SaveManager.game_data.objectives.has(wp.objective_id) and not SaveManager.game_data.objectives[wp.objective_id].done:
			_cached_objective = wp
			break
