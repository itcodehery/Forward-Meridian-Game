extends SceneTree

func _initialize():
	print("Fixing Node references...")
	
	# Manually instantiate missing autoloads so scripts can compile!
	var sm = load("res://scripts/save_manager.gd").new()
	sm.name = "SaveManager"
	root.add_child(sm)
	
	var sub = load("res://ui/resources/subtitle_manager.gd")
	if sub:
		var sub_inst = sub.new()
		sub_inst.name = "SubtitleManager"
		root.add_child(sub_inst)
		
	var lm = load("res://scripts/log_manager.gd")
	if lm:
		var lm_inst = lm.new()
		lm_inst.name = "LogManager"
		root.add_child(lm_inst)
		
	var mb = load("res://ui/resources/mission_brief.gd")
	if mb:
		var mb_inst = mb.new()
		mb_inst.name = "MissionBrief"
		root.add_child(mb_inst)
		
	var to = load("res://ui/resources/tutorial_overlay.gd")
	if to:
		var to_inst = to.new()
		to_inst.name = "TutorialOverlay"
		root.add_child(to_inst)
	
	var head_packed = load("/tmp/level_1_head.scn")
	var curr_packed = load("res://levels/level_1/level_1.scn")
	
	var head_root = head_packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var curr_root = curr_packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	
	var head_nodes = {}
	_collect_nodes(head_root, head_root, head_nodes)
	
	var curr_nodes = {}
	_collect_nodes(curr_root, curr_root, curr_nodes)
	
	var restored_count = 0
	
	for path in curr_nodes:
		if head_nodes.has(path):
			var c_node = curr_nodes[path]
			var h_node = head_nodes[path]
			
			var h_script = h_node.get_script()
			if h_script != null:
				for prop in h_node.get_property_list():
					if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
						var h_val = h_node.get(prop.name)
						
						# Fix Node References!
						if h_val is Node:
							var relative_path = head_root.get_path_to(h_val)
							var mapped_node = curr_root.get_node_or_null(relative_path)
							if mapped_node:
								c_node.set(prop.name, mapped_node)
								print("  Fixed Node var: ", path, " / ", prop.name, " -> ", relative_path)
								restored_count += 1
							else:
								print("  WARNING: Could not find mapped node for: ", relative_path)
						elif h_val is NodePath:
							# Sometimes NodePaths might be needed if they were cleared
							c_node.set(prop.name, h_val)
	
	if restored_count > 0:
		var new_packed = PackedScene.new()
		new_packed.pack(curr_root)
		ResourceSaver.save(new_packed, "res://levels/level_1/level_1.scn")
		print("SUCCESS! Restored ", restored_count, " node references and saved back to level_1.scn")
	else:
		print("No node references found to restore.")
		
	quit()

func _collect_nodes(node, root_node, dict):
	var path = str(root_node.get_path_to(node))
	if path == "": path = "."
	dict[path] = node
	for child in node.get_children():
		_collect_nodes(child, root_node, dict)
