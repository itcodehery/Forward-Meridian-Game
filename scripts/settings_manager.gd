extends Node

const CONFIG_PATH = "user://settings.cfg"

var configurable_actions = [
	"move_forward", "move_backward", "move_left", "move_right", "ui_crouch",
	"switch_weapon", "melee_strike", "drop_weapon",
	"fire", "reload", "interact", "ads",
	"grapple", "grenade", "toggle_inventory", "scan"
]

	# Audio & Video Settings
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var subtitles_enabled: bool = true
var fullscreen: bool = false

# Accessibility Settings
var tutorials_enabled: bool = true

func _ready():
	_ensure_sfx_bus()
	load_settings()

func _ensure_sfx_bus():
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var new_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(new_idx, "SFX")
		AudioServer.set_bus_send(new_idx, "Master")

func save_settings():
	var config = ConfigFile.new()
	# Controls
	for action in configurable_actions:
		if InputMap.has_action(action):
			var events = InputMap.action_get_events(action)
			if events.size() > 0:
				config.set_value("controls", action, events[0])
	
	# Video
	config.set_value("video", "fullscreen", fullscreen)
	
	# Audio
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "subtitles_enabled", subtitles_enabled)
	
	# Accessibility
	config.set_value("accessibility", "tutorials_enabled", tutorials_enabled)
	
	config.save(CONFIG_PATH)

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err != OK:
		# Apply defaults if no config
		apply_video_settings()
		apply_audio_settings()
		return
	
	# Load Controls
	for action in configurable_actions:
		if config.has_section_key("controls", action):
			var event = config.get_value("controls", action)
			if InputMap.has_action(action):
				InputMap.action_erase_events(action)
				InputMap.action_add_event(action, event)
	
	# Load Video
	fullscreen = config.get_value("video", "fullscreen", false)
	apply_video_settings()
	
	# Load Audio
	master_volume = config.get_value("audio", "master_volume", 1.0)
	sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
	subtitles_enabled = config.get_value("audio", "subtitles_enabled", true)
	apply_audio_settings()

	# Load Accessibility
	tutorials_enabled = config.get_value("accessibility", "tutorials_enabled", true)

func apply_video_settings():
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func apply_audio_settings():
	var master_idx = AudioServer.get_bus_index("Master")
	var sfx_idx = AudioServer.get_bus_index("SFX")
	
	if master_idx != -1:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(master_volume))
	if sfx_idx != -1:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sfx_volume))
