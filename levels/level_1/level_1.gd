extends Node3D

# --- Level Configuration & Atmosphere ---
@export_group("Atmosphere")
## Drag your music file (.wav, .ogg, .mp3) here
@export var background_music: AudioStream 
@export var combat_music: AudioStream
@export var ambient_sound: AudioStream # <--- NEW AMBIENCE SLOT
## Adjust volume (in decibels)
@export var music_volume: float = -10.0 
@export var ambient_volume: float = -15.0 # <--- NEW AMBIENCE VOLUME

# --- Mission Configuration ---
@export_group("Mission Info")
@export var mission_name: String = "The Package"
@export var mission_goal: String = "Retrieve an important package from the past for Vischem."

# --- Node References ---
@onready var player_spawn = $Spawns/PlayerSpawn
@onready var turret_markers = [
	$Spawns/TurretSpawn1,
	$Spawns/TurretSpawn2,
	$Spawns/TurretSpawn3
]

@onready var music_player = AudioStreamPlayer.new()
@onready var ambient_player = AudioStreamPlayer.new() # <--- NEW PLAYER NODE
@export var stop_area: CSGBox3D
@export var ambush_spawner: Node3D # Drag your 'Drones' Spawner node here!


func _ready():
	# 1. Setup Atmosphere
	_setup_background_music()

	# 2. Register the level's objectives
	SaveManager.register_objective("find_weapon", "Find a weapon to defend yourself")
	SaveManager.register_objective("kill_turrets", "Destroy all security turrets (0/3)")
	SaveManager.register_objective("get_key", "Find the Security Keycard")
	SaveManager.register_objective("override_elevator", "Override Quadrant Security Measures")
	SaveManager.register_objective("halt", "Unlock Quadrant B")
	
	SaveManager.register_objective("server","Find a Terminal in Quadrant B")
	SaveManager.register_objective("unlock","Initiate Hack to Unlock Quadrant C")
	SaveManager.register_objective("move","Move to Quadrant C")
	SaveManager.register_objective("uphold","Engage Asterisk Forces")
	
	SaveManager.register_objective("unlock_d","Unlock Quadrant D")
	SaveManager.register_objective("find","Find the Package")
	SaveManager.register_objective("ready","Get Ready for Extraction")
	
	# 3. Spawn everything!
	_spawn_entities()
	if SaveManager.game_data.objectives.has("fight_security") and not SaveManager.game_data.objectives["fight_security"].done:
		var total_drones = get_tree().get_nodes_in_group("drones").size()
		if total_drones > 0:
			SaveManager.update_objective_text("fight_security", "Fight through Asterisk Security (" + str(total_drones) + " left)")
	
	# 4. Listen for objective completions to trigger level events
	SaveManager.objective_updated.connect(_on_objective_updated)
	
	# 5. Check current state (in case they loaded a save midway through)
	_sync_level_state()

func _setup_background_music():
	if background_music:
		add_child(music_player)
		music_player.stream = background_music
		music_player.volume_db = music_volume
		music_player.autoplay = true
		music_player.bus = "Music" 
		music_player.play()
		print("Director: Background music started: ", background_music.resource_path)
	else:
		print("Director Warning: No background music assigned to the level!")
	
	# 2. Prepare the Ambience (but DON'T play it yet)
	if ambient_sound:
		add_child(ambient_player)
		ambient_player.stream = ambient_sound
		ambient_player.volume_db = ambient_volume
		ambient_player.bus = "Master" 
		
		# Check if the intro sequence is in the scene tree.
		# (Make sure "IntroDirector" perfectly matches the node name in your Scene tree!)
		if has_node("IntroDirector"):
			print("Director: Waiting for IntroSequence to finish before starting ambience.")
		else:
			# If there's no intro (e.g. loading a save mid-level), start immediately
			start_ambience()

# --- NEW FUNCTION ---
func start_ambience():
	if ambient_player and ambient_sound and not ambient_player.playing:
		ambient_player.play()
		print("Director: Ambient background noise started.")

func _spawn_entities():
	# --- 1. SPAWN THE PLAYER ---
	var player = get_tree().get_first_node_in_group("players")
	var ui = get_tree().get_first_node_in_group("ui")
	
	if player and ui:
		player.health_changed.connect(ui._on_health_changed)
		player.stamina_changed.connect(ui._on_stamina_changed)
		player.get_node("WeaponHandler").ammo_changed.connect(ui._on_ammo_changed)
		
	if not player:
		var player_instance = preload("res://actors/player/player.tscn").instantiate()
		add_child(player_instance)
		# Copy transform to get both Spawn Position AND Rotation (facing direction)
		player_instance.global_transform = player_spawn.global_transform
	else:
		if SaveManager.game_data.player_stats.pos_x == 0:
			player.global_transform = player_spawn.global_transform
		
	# --- 2. SPAWN THE TURRETS (FIXED ROTATION) ---
	if not SaveManager.game_data.objectives.has("kill_turrets") or not SaveManager.game_data.objectives["kill_turrets"].done:
		var turret_scene = preload("res://actors/enemies/turret/turret.tscn")
		for marker in turret_markers:
			if marker:
				var turret_instance = turret_scene.instantiate()
				add_child(turret_instance)
				turret_instance.add_to_group("turrets")
				
				# THE FIX: Use global_transform to inherit the Marker3D's rotation
				turret_instance.global_transform = marker.global_transform
				
				print("Director: Spawned Turret at ", marker.name, " with rotation: ", marker.rotation_degrees)

func _sync_level_state():
	pass 

func _on_objective_updated(_text):
	print("on_objective_updated() called")
	var obj_weapon = SaveManager.game_data.objectives.get("find_weapon")
	if obj_weapon and obj_weapon.done:
		print("Director: Weapon found! Opening door...")
		
	var obj_turret = SaveManager.game_data.objectives.get("kill_turrets")
	if obj_turret and obj_turret.done:
		print("Director: All Turrets destroyed! Powering up elevator...")
		
	var obj_security = SaveManager.game_data.objectives.get("fight_security")
	if obj_security and obj_security.done:
		print("Director: Asterisk Security neutralized! Access to elevator controls granted.")
	
	var package_collected = SaveManager.game_data.objectives.get("find")
	if package_collected and package_collected.done:
		print("Package collected. Prepare for Mission Ending.")
		stop_area.queue_free()
		if ambush_spawner and ambush_spawner.has_method("spawn_enemies"):
			ambush_spawner.spawn_enemies()

func fade_out_music(duration: float = 2.0):
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, duration)
	await tween.finished
	music_player.stop()
	
func trigger_combat_music():
	if not combat_music or music_player.stream == combat_music:
		return # Don't do anything if we don't have music or it's already playing
		
	# Quick crossfade: fade out the ambient track
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, 1.0)
	await tween.finished
	
	# Swap the track and fade it back in
	music_player.stream = combat_music
	music_player.play()
	tween = create_tween()
	tween.tween_property(music_player, "volume_db", music_volume, 0.5)


func _on_kill_zone_body_entered(body: Node3D):
	if body.is_in_group("players"):
		body.die()

func fade_out_ambience(duration: float = 2.0):
	if ambient_player and ambient_player.playing:
		var tween = create_tween()
		tween.tween_property(ambient_player, "volume_db", -80.0, duration)
		await tween.finished
		ambient_player.stop()
