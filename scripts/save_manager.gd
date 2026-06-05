extends Node

signal objective_updated(text: String)

const SAVE_DIR = "user://saves/"

# Tracks the exact file we are currently playing on
var current_save_path: String = ""

# The master dictionary that holds everything persistent
var game_data: Dictionary = {
	"save_date": "",      # For the UI to display
	"unix_time": 0,       # For the code to sort by newest
	"current_level": "level_1",
	"objectives": {}, 
	"player_stats": {
		"health": 100.0,
		"armor": 0.0,
		"pos_x": 0.0,
		"pos_y": 0.0,
		"pos_z": 0.0
	}
}

var checkpoint_timer: Timer

func _ready() -> void:
	# 1. Ensure the saves directory exists on the player's hard drive
	DirAccess.make_dir_absolute(SAVE_DIR)
	
	# 2. Setup the Checkpoint Timer (but don't autostart it until a level loads)
	checkpoint_timer = Timer.new()
	add_child(checkpoint_timer)
	checkpoint_timer.wait_time = 180.0 
	checkpoint_timer.timeout.connect(create_checkpoint)

# ---------------------------------------------------------
# MULTI-SAVE SYSTEM LOGIC
# ---------------------------------------------------------

func save_game(make_new_slot: bool = false) -> void:
	# If we don't have a save path yet, or we explicitly asked for a new slot, generate one
	if current_save_path == "" or make_new_slot:
		var time_string = Time.get_datetime_string_from_system().replace(":", "-")
		current_save_path = SAVE_DIR + "save_" + time_string + ".json"
		
	# Update the timestamp metadata so the Load Menu knows exactly when this was saved
	game_data["unix_time"] = Time.get_unix_time_from_system()
	
	# Format a nice readable date for the UI (e.g. "2026-05-20 14:30")
	var dict = Time.get_datetime_dict_from_system()
	game_data["save_date"] = "%04d-%02d-%02d %02d:%02d" % [dict.year, dict.month, dict.day, dict.hour, dict.minute]

	var file = FileAccess.open(current_save_path, FileAccess.WRITE)
	if file:
		file.store_line(JSON.stringify(game_data))
		file.close()
		print("Game Saved to: ", current_save_path)
	else:
		printerr("Failed to open save file for writing.")

func load_game(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		printerr("Save file does not exist: ", file_path)
		return false
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_string = file.get_line()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_string) == OK:
			game_data.merge(json.get_data(), true)
			current_save_path = file_path # Lock us into this save slot
			print("Game Loaded successfully from: ", current_save_path)
			
			# Start the autosave loop now that we are in-game
			checkpoint_timer.start() 
			return true
			
	printerr("Failed to parse save file JSON.")
	return false

# --- NEW: Helper functions for your Main Menu UI ---

func get_all_saves() -> Array:
	var saves = []
	var dir = DirAccess.open(SAVE_DIR)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var full_path = SAVE_DIR + file_name
				# Read just enough of the file to get its metadata for the UI list
				var file = FileAccess.open(full_path, FileAccess.READ)
				if file:
					var json = JSON.new()
					if json.parse(file.get_line()) == OK:
						var data = json.get_data()
						# Package the metadata to send to the UI
						saves.append({
							"path": full_path,
							"date": data.get("save_date", "Unknown Date"),
							"level": data.get("current_level", "Unknown"),
							"unix_time": data.get("unix_time", 0)
						})
			file_name = dir.get_next()
			
	# Sort the array so the newest saves are at the top (Index 0)
	saves.sort_custom(func(a, b): return a["unix_time"] > b["unix_time"])
	return saves

func continue_game() -> bool:
	var saves = get_all_saves()
	if saves.size() > 0:
		# Load the very first item in the sorted list (the newest one)
		var latest_save_path = saves[0]["path"]
		return load_game(latest_save_path)
	return false

# ---------------------------------------------------------
# GAMEPLAY TRIGGERS
# ---------------------------------------------------------

func new_game() -> void:
	# Reset everything to defaults
	game_data.objectives.clear()
	game_data.current_level = "level_1"
	game_data.player_stats = {
		"health": 100.0, "armor": 0.0,
		"pos_x": 0.0, "pos_y": 0.0, "pos_z": 0.0
	}
	
	# Clear the current path so save_game() is forced to create a brand new file
	current_save_path = ""
	save_game(true) 
	
	checkpoint_timer.start()

func create_checkpoint() -> void:
	var player = get_tree().get_first_node_in_group("players")
	if player:
		game_data.player_stats.health = player.health
		game_data.player_stats.armor = player.armor
		game_data.player_stats.pos_x = player.global_position.x
		game_data.player_stats.pos_y = player.global_position.y
		game_data.player_stats.pos_z = player.global_position.z
		
		# False means we overwrite the file we are currently playing on
		save_game(false) 
		print("Auto-Checkpoint Created!")

func load_next_level() -> void:
	var current_level_string = game_data.current_level
	var parts = current_level_string.split("_")
	
	if parts.size() == 2:
		var next_level_string = "level_" + str(parts[1].to_int() + 1)
		
		game_data.current_level = next_level_string
		game_data.objectives.clear() 
		game_data.player_stats.pos_x = 0.0
		game_data.player_stats.pos_y = 0.0
		game_data.player_stats.pos_z = 0.0
		
		# Save progress over the current slot
		save_game(false)
		
		get_tree().change_scene_to_file("res://levels/" + next_level_string + ".tscn")

# ---------------------------------------------------------
# OBJECTIVE SYSTEM (Unchanged)
# ---------------------------------------------------------
func register_objective(id: String, text: String) -> void:
	if not game_data.objectives.has(id):
		game_data.objectives[id] = {
			"text": text, 
			"done": false,
			"order": game_data.objectives.size() 
		}
		save_game(false)
	
	if not game_data.objectives[id].done:
		objective_updated.emit(text)

func complete_objective(id: String) -> void:
	if game_data.objectives.has(id) and not game_data.objectives[id].done:
		game_data.objectives[id].done = true
		save_game(false)
		_check_mission_complete()

func _check_mission_complete() -> void:
	if game_data.objectives.is_empty(): return
		
	var all_done = true
	var sorted_keys = game_data.objectives.keys()
	sorted_keys.sort_custom(func(a, b): return game_data.objectives[a].get("order", 0) < game_data.objectives[b].get("order", 0))
	
	for obj_id in sorted_keys:
		if not game_data.objectives[obj_id].done:
			all_done = false
			objective_updated.emit(game_data.objectives[obj_id].text)
			break
	
	if all_done:
		load_next_level()

func update_objective_text(id: String, new_text: String) -> void:
	if game_data.objectives.has(id):
		game_data.objectives[id].text = new_text
		objective_updated.emit(new_text)
