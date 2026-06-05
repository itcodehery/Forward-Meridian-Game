extends Node3D

@export_group("Targeting")
@export var target_door: Node3D
@export var ambush_spawner: Node3D
@export_group("Logic")  
@export var objective_id: String = "override_elevator"
@export var switch_audio: AudioStream

var is_activated: bool = false
@onready var audio_player = $AudioStreamPlayer3D

func _ready() -> void:
	print("Terminal ready")
	print("  ambush_spawner: ", ambush_spawner)
	print("  target_door: ", target_door)

## This is what the player calls. It's on the ROOT Node3D, so the
## player script must call body.get_parent().interact() — see fix below.
func interact(_player):
	if is_activated:
		return

	is_activated = true
	print("Security switch activated!")
	if ambush_spawner and ambush_spawner.has_method("spawn_enemies"):
		ambush_spawner.spawn_enemies()
	else:
		push_warning("Security Switch: No ambush_spawner assigned!")
	# 1. Play audio
	if switch_audio:
		audio_player.stream = switch_audio
		audio_player.play()

	# 2. Update the status flash (uses display_status from your UI script)
	var ui = get_tree().get_first_node_in_group("interface")
	if ui and ui.has_method("display_status"):
		ui.display_status("SECURITY OVERRIDDEN - ACCESS GRANTED")

	# 3. Mark objective complete in SaveManager
	if SaveManager.has_method("complete_objective"):
		SaveManager.complete_objective(objective_id)

	# 4. Unlock the door
	if target_door and target_door.has_method("unlock_security"):
		target_door.unlock_security()
	else:
		push_warning("SecuritySwitch: No target_door assigned!")

## Called by the player's PickupArea to show the prompt
func get_interact_text() -> String:
	if is_activated:
		return ""
	return "OVERRIDE SECURITY TERMINAL"
