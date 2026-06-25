extends Node

func _ready():
	print("Verifying scene...")
	var scene = load("res://ui/menus/settings_menu.tscn")
	if scene:
		var instance = scene.instantiate()
		add_child(instance)
		print("Successfully instantiated and added to tree.")
	else:
		print("Failed to load scene.")
	
	get_tree().quit()
