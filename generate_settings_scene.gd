extends Node

func _ready():
	print("Starting generation...")
	var menu = preload("res://ui/menus/settings_menu.gd").new()
	# Call _build_ui manually
	menu._build_ui()
	
	# Set owners recursively
	_set_owner(menu, menu)
	
	var packed = PackedScene.new()
	packed.pack(menu)
	var err = ResourceSaver.save(packed, "res://ui/menus/settings_menu_generated.tscn")
	if err == OK:
		print("Successfully saved settings menu to res://ui/menus/settings_menu_generated.tscn")
	else:
		print("Error saving: ", err)
	
	get_tree().quit()

func _set_owner(node: Node, owner_node: Node):
	for child in node.get_children():
		child.owner = owner_node
		_set_owner(child, owner_node)
