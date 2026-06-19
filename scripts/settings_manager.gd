extends Node

const CONFIG_PATH = "user://controls.cfg"

var configurable_actions = [
	"ui_up", "ui_down", "ui_left", "ui_right", "ui_crouch",
	"weapon_1", "weapon_2", "weapon_3", "drop_weapon",
	"fire", "reload", "interact", "ads",
	"grapple", "grenade", "toggle_inventory"
]

func _ready():
	load_controls()

func save_controls():
	var config = ConfigFile.new()
	for action in configurable_actions:
		if InputMap.has_action(action):
			var events = InputMap.action_get_events(action)
			if events.size() > 0:
				config.set_value("controls", action, events[0])
	config.save(CONFIG_PATH)

func load_controls():
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err != OK:
		return
	
	for action in configurable_actions:
		if config.has_section_key("controls", action):
			var event = config.get_value("controls", action)
			if InputMap.has_action(action):
				InputMap.action_erase_events(action)
				InputMap.action_add_event(action, event)
