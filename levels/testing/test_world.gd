extends Node3D

@onready var player_spawn = $PlayerSpawn

func _ready():
	# Only spawn the player, ignore all the mission/save data logic
	_spawn_test_player()

func _spawn_test_player():
	# 1. Instantiate the player
	var player_scene = preload("res://actors/player/player.tscn")
	var player_instance = player_scene.instantiate()
	add_child(player_instance)
	
	# 2. Position the player at the Marker3D
	if player_spawn:
		player_instance.global_transform = player_spawn.global_transform
		
	# 3. Hook up the UI (Optional, but useful for testing stamina/ammo)
	var ui = get_tree().get_first_node_in_group("ui")
	if ui:
		if player_instance.has_signal("health_changed"):
			player_instance.health_changed.connect(ui._on_health_changed)
		if player_instance.has_signal("stamina_changed"):
			player_instance.stamina_changed.connect(ui._on_stamina_changed)
			
		# Safely check for the weapon handler before connecting
		var weapon_handler = player_instance.get_node_or_null("WeaponHandler")
		if weapon_handler and weapon_handler.has_signal("ammo_changed"):
			weapon_handler.ammo_changed.connect(ui._on_ammo_changed)
