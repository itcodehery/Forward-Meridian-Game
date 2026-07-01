extends Node3D

# --- Level Configuration & Atmosphere ---
@export_group("Atmosphere")
@export var background_music: AudioStream 
@export var combat_music: AudioStream
@export var ambient_sound: AudioStream 
@export var music_volume: float = -10.0 
@export var ambient_volume: float = -15.0 

# --- Mission Configuration ---
@export_group("Mission Info")
@export var mission_name: String = "02: The Ghost"
@export var mission_goal: String = "Infiltrate the Thar Desert Mining Outpost, descend into the hidden biolab, and extract the data."

# --- Node References ---
@onready var player_spawn = $Spawns/PlayerSpawn if has_node("Spawns/PlayerSpawn") else null
@onready var music_player = AudioStreamPlayer.new()
@onready var ambient_player = AudioStreamPlayer.new() 

func _ready():
	_setup_background_music()
	
	# Clear previous level inventory for a fresh start in Level 2
	SaveManager.game_data.inventory = {}

	# 1. Register the level's objectives (Branching)
	SaveManager.register_objective("drive_outpost", "Drive the buggy through the tunnel to reach the outpost border.")
	
	# BRANCH 1: LOUD
	SaveManager.register_objective("shoot_turrets", "Shoot down the turrets at the end of the tunnel.")
	SaveManager.register_objective("main_road", "Take the main road and destroy perimeter defenses.")
	SaveManager.register_objective("assault_base", "Assault the main perimeter gate and enter the outpost.")
	
	# BRANCH 2: STEALTH
	SaveManager.register_objective("find_secret", "Find the secret maintenance entrance outside the outpost.")
	SaveManager.register_objective("enter_maintenance", "Walk toward the maintenance entrance and breach it.")
	SaveManager.register_objective("fight_maintenance", "Neutralize the maintenance soldiers.")
	SaveManager.register_objective("infiltrate_stealth", "Infiltrate the outpost via stealth routes.")
	
	# CONVERGENCE
	SaveManager.register_objective("search_barracks", "Search the outer barracks for security credentials.")
	SaveManager.register_objective("unlock_inner", "Unlock the inner circular compound.")
	SaveManager.register_objective("infiltrate_admin", "Infiltrate the Administration Building.")
	SaveManager.register_objective("locate_rehman", "Find Sgt. Abdul Rehman's office.")
	SaveManager.register_objective("get_elevator_code", "Obtain the Mega-Drill Elevator override code.")
	SaveManager.register_objective("reach_drill", "Make your way to the central Mega-Drill structure.")
	SaveManager.register_objective("activate_power", "Restore power to the Mega-Drill elevator.")
	SaveManager.register_objective("descend", "Take the elevator to the underground dig site.")
	SaveManager.register_objective("navigate_caves", "Navigate the subterranean cavern.")
	SaveManager.register_objective("find_lab", "Locate the hidden Vischem biolab.")
	SaveManager.register_objective("steal_data", "Steal the classified data from the mainframe.")
	SaveManager.register_objective("escape_leak", "Survive the containment breach and escape!")
	
	# 3. Spawn everything!
	_spawn_entities()
	
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
	
	if ambient_sound:
		add_child(ambient_player)
		ambient_player.stream = ambient_sound
		ambient_player.volume_db = ambient_volume
		ambient_player.bus = "Master" 
		
		if not has_node("IntroDirector"):
			start_ambience()

func start_ambience():
	if ambient_player and ambient_sound and not ambient_player.playing:
		ambient_player.play()

func _spawn_entities():
	var player = get_tree().get_first_node_in_group("players")
	var ui = get_tree().get_first_node_in_group("ui")
	
	if player and ui:
		if not player.health_changed.is_connected(ui._on_health_changed): player.health_changed.connect(ui._on_health_changed)
		if not player.stamina_changed.is_connected(ui._on_stamina_changed): player.stamina_changed.connect(ui._on_stamina_changed)
		var wh = player.find_child("WeaponHandler", true, false)
		if wh and not wh.ammo_changed.is_connected(ui._on_ammo_changed):
			wh.ammo_changed.connect(ui._on_ammo_changed)
		
	if not player:
		var player_instance = preload("res://actors/player/player.tscn").instantiate()
		add_child(player_instance)
		if player_spawn:
			player_instance.global_transform = player_spawn.global_transform
	else:
		if SaveManager.game_data.player_stats.pos_x == 0 and player_spawn:
			player.global_transform = player_spawn.global_transform

func _sync_level_state():
	var player = get_tree().get_first_node_in_group("players")
	if player:
		if SaveManager.game_data.player_stats.pos_x != 0 or SaveManager.game_data.player_stats.pos_y != 0 or SaveManager.game_data.player_stats.pos_z != 0:
			player.global_position = Vector3(
				SaveManager.game_data.player_stats.pos_x,
				SaveManager.game_data.player_stats.pos_y,
				SaveManager.game_data.player_stats.pos_z
			)
			player.health = SaveManager.game_data.player_stats.health
			player.armor = SaveManager.game_data.player_stats.armor

func _on_objective_updated(_text):
	pass

func fade_out_music(duration: float = 2.0):
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, duration)
	await tween.finished
	music_player.stop()
	
func trigger_combat_music():
	if not combat_music or music_player.stream == combat_music:
		return 
		
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, 1.0)
	await tween.finished
	
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
