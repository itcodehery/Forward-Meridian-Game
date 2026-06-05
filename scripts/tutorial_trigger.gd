extends Area3D

@export var tutorial_name: String = "intro"

func _on_body_entered(body: Node3D):
	# Verified your group name is "players"
	if body.is_in_group("players"):
		# Find the overlay in your level scene
		# Pro-tip: Give your TutorialOverlay a unique name or put it in a group
		var overlay = get_tree().get_first_node_in_group("tutorial_ui")
		
		if overlay:
			overlay.start_tutorial(tutorial_name)
			queue_free() # Delete trigger so it doesn't repeat
