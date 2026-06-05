extends Area3D

# Preload your outro scene here. 
const OUTRO_SCENE = preload("res://levels/level_1/outro_sequence.tscn") 

func get_prompt() -> String:
	return "[E] Secure Med Package"

func interact(player):
	# --- OBJECTIVE LOGIC ---
	if SaveManager.game_data.objectives.has("find"):
		if not SaveManager.game_data.objectives["find"].done:
			SaveManager.complete_objective("find")
			
	# --- TRIGGER OUTRO ---
	if OUTRO_SCENE:
		var outro_instance = OUTRO_SCENE.instantiate()
		
		# Add it to the main level/scene tree. 
		# We attach it to the current_scene so it survives when we delete the package!
		get_tree().current_scene.add_child(outro_instance)
	
	# Delete the entire med_package (the root Node3D)
	get_parent().queue_free()
