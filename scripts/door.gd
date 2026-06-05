extends Node3D

@export_group("Lock Settings")
## If true, the switch MUST be flipped first
@export var is_security_locked: bool = false 
## If true, requires a keycard (after security is cleared)
@export var is_locked: bool = false
@export var is_quadrant_locked: bool = false
@export var required_key_id: String = "" 
var prompt_text: String = "OPEN DOOR"

@export_group("Auto-Close")
@export var auto_close_delay: float = 3.0

var is_open: bool = false
var bodies_in_way: int = 0

@onready var anim_player = $AnimationPlayer
@onready var audio_player = $AudioStreamPlayer3D
@onready var deny_player = $AudioStreamPlayer3D2
@onready var close_timer = $Timer
@onready var safety_zone = $SafetyZone

func _ready():
	close_timer.wait_time = auto_close_delay
	close_timer.one_shot = true
	
	if is_security_locked or is_quadrant_locked or is_locked:
		prompt_text = "OVERRIDE PANEL"
	
	# Connect Signals
	close_timer.timeout.connect(_on_timer_timeout)
	if safety_zone:
		safety_zone.body_entered.connect(_on_safety_zone_entered)
		safety_zone.body_exited.connect(_on_safety_zone_exited)

## Called by the Security Switch
func unlock_security():
	is_security_locked = false
	print("Door security lock released.")

## Called by the Quadrant Switch
func unlock_quadrant():
	is_quadrant_locked = false
	print("Quadrant security lock released.")

func play_deny():
	print("inside play deny")
	if deny_player.stream:
		deny_player.play()
	else:
		print("wtf is happening")

func interact(player):
	# 1. Check Environmental/Level Security First
	if is_security_locked:
		_show_ui_status("ACCESS DENIED - MAIN SECURITY OVERRIDE REQUIRED")
		play_deny()
		return # Stop here

	elif is_quadrant_locked:
		_show_ui_status("ACCESS DENIED - QUADRANT ON LOCKDOWN")
		play_deny()
		return
		
	# 2. Check Personal Keycard
	var inventory = player.get_node("Inventory")
	if is_locked:
		if inventory and inventory.has_item_id(required_key_id):
			print("Key found! Unlocking...")
			unlock_and_open()
			if inventory.has_method("remove_item_id"):
				inventory.remove_item_id(required_key_id)
		else:
			_show_ui_status("LOCKED - REQUIRES " + required_key_id.to_upper())
			play_deny()
	else:
		toggle_door()

func unlock_and_open():
	is_locked = false 
	if not is_open:
		toggle_door()

func toggle_door():
	if is_open:
		anim_player.play_backwards("open")
		audio_player.play()
		close_timer.stop()
		prompt_text = "OPEN DOOR"
	else:
		anim_player.play("open")
		audio_player.play()
		close_timer.start()
		prompt_text = "CLOSE DOOR"
	
	is_open = !is_open

## --- Safety & Auto-Close Logic ---
func _on_safety_zone_entered(body):
	if body is CharacterBody3D:
		bodies_in_way += 1
		close_timer.stop()

func _on_safety_zone_exited(body):
	if body is CharacterBody3D:
		bodies_in_way -= 1
		if is_open and bodies_in_way <= 0:
			close_timer.start()

func _on_timer_timeout():
	if is_open:
		if bodies_in_way > 0:
			close_timer.start()
		else:
			toggle_door()

func _show_ui_status(message: String):
	var ui = get_tree().get_first_node_in_group("interface")
	if ui and ui.has_method("display_status"):
		ui.display_status(message)
