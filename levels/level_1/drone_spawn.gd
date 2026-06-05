extends Node3D

# This exposes a slot in the Inspector so you can drag and drop your Drone scene
@export var enemy_scene: PackedScene 

# We set this so the encounter doesn't accidentally trigger twice
var has_spawned = false 

func spawn_enemies():
	print("called spawn enemies")
	if has_spawned: return
	has_spawned = true
	
	# Loop through all the Marker3Ds we placed inside this node
	for spawn_point in get_children():
		if spawn_point is Marker3D:
			# 1. Create a brand new copy of the drone in memory
			var new_enemy = enemy_scene.instantiate()
			
			# 2. Add it to the level
			# (We add it to the main level tree so it isn't trapped inside the spawner)
			get_parent().add_child(new_enemy)
			
			# 3. Teleport it to the Marker's exact location and rotation
			new_enemy.global_position = spawn_point.global_position
			new_enemy.global_rotation = spawn_point.global_rotation
			
			# Optional: Give it a slight upward bump so it doesn't clip into the floor on spawn
			new_enemy.global_position.y += 0.5
