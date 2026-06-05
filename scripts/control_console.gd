extends Node3D

var is_active = true
var hold_time = 2.0
var prompt_text = "OVERRIDE" # The player script will read this!
# Grab the light so we can turn it green when hacked!
@onready var status_light = $StaticBody3D/OmniLight3D
@onready var audio_player = $AudioStreamPlayer3D 
@export var quadrant_door: Node3D

func interact(_player):
	if not is_active:
		return # Prevent the player from spamming the console
		
	is_active = false
	print("Console Hacked!")
	
	# 1. Visual Feedback
	if status_light:
		status_light.light_color = Color(0, 1, 0) # Turn the light Green
	
	audio_player.play()
	# 2. Complete the objective!
	SaveManager.complete_objective("halt")
	
	# 3. UI Feedback
	var ui = get_tree().get_first_node_in_group("interface")
	if ui:
		# Flash a cool success message
		ui.display_status("SYSTEM OVERRIDE SUCCESSFUL\nQUADRANT B UNLOCKED")
		
		# Optional: If you updated your player to use the detailed interaction prompt, 
		# this will clear it off the screen since the console is dead now.
		if ui.has_method("set_interaction_prompt"):
			ui.set_interaction_prompt("", false)
	
	# 4. Unlock Quadrant Door
	if quadrant_door and quadrant_door.has_method("unlock_quadrant"):
		quadrant_door.unlock_quadrant()
		
