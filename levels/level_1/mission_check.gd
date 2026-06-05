extends Area3D

@export var ambush_spawner: Node3D # Drag your 'Drones' Spawner node here!
var is_active = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
		# Connect the Area3D signals
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("players"):
		is_active = true
		SaveManager.complete_objective("move")
		if ambush_spawner and ambush_spawner.has_method("spawn_enemies"):
			ambush_spawner.spawn_enemies()
		else:
			push_warning("Quarantine Terminal: No ambush_spawner assigned!")
	
		if owner.has_method("trigger_combat_music"):
			owner.trigger_combat_music()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if is_active:
		var remaining_drones = get_tree().get_nodes_in_group("drones").size()
		
		if remaining_drones <= 0:
			# All drones are dead! Unlock the terminal for Part 2
			SaveManager.complete_objective("uphold")
			is_active = false
