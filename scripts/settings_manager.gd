extends Node

const CONFIG_PATH = "user://settings.cfg"

signal graphics_updated

var configurable_actions = [
	"move_forward", "move_backward", "move_left", "move_right", "ui_crouch",
	"switch_weapon", "melee_strike", "drop_weapon",
	"fire", "reload", "interact", "ads",
	"grapple", "grenade", "toggle_inventory", "scan"
]

# --- Audio Settings ---
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0
var dialog_volume: float = 1.0
var subtitles_enabled: bool = true

# --- Video Settings ---
var display_mode: int = 1 # 0: Windowed, 1: Fullscreen, 2: Borderless
var resolution: Vector2i = Vector2i(1920, 1080)
var vsync_mode: int = 1 # 0: Off, 1: On, 2: Adaptive, 3: Mailbox
var fps_cap: int = 0 # 0: Unlimited, 30, 60, 120, 144
var fsr_mode: int = 0 # 0: Off, 1: Quality (0.77), 2: Balanced (0.67), 3: Performance (0.5), 4: Ultra Performance (0.33)
var anti_aliasing: int = 2 # 0: Off, 1: FXAA, 2: TAA, 3: MSAA 2x, 4: MSAA 4x, 5: MSAA 8x
var shadow_quality: int = 2 # 0: Low, 1: Medium, 2: High, 3: Ultra
var sdfgi_enabled: bool = true
var bloom_enabled: bool = true

# --- Accessibility Settings ---
var tutorials_enabled: bool = true

func _ready():
	_ensure_audio_buses()
	load_settings()

func _ensure_audio_buses():
	var buses = ["SFX", "Music", "Dialog"]
	for bus in buses:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var new_idx = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(new_idx, bus)
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
	config.set_value("video", "display_mode", display_mode)
	config.set_value("video", "resolution_x", resolution.x)
	config.set_value("video", "resolution_y", resolution.y)
	config.set_value("video", "vsync_mode", vsync_mode)
	config.set_value("video", "fps_cap", fps_cap)
	config.set_value("video", "fsr_mode", fsr_mode)
	config.set_value("video", "anti_aliasing", anti_aliasing)
	config.set_value("video", "shadow_quality", shadow_quality)
	config.set_value("video", "sdfgi_enabled", sdfgi_enabled)
	config.set_value("video", "bloom_enabled", bloom_enabled)
	
	# Audio
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "dialog_volume", dialog_volume)
	config.set_value("audio", "subtitles_enabled", subtitles_enabled)
	
	# Accessibility
	config.set_value("accessibility", "tutorials_enabled", tutorials_enabled)
	
	var err = config.save(CONFIG_PATH)
	if err != OK:
		print("ERROR: Failed to save settings. Error code: ", err)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_settings()

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err != OK:
		apply_video_settings()
		apply_audio_settings()
		return
	
	# Controls
	for action in configurable_actions:
		if config.has_section_key("controls", action):
			var event = config.get_value("controls", action)
			if InputMap.has_action(action):
				InputMap.action_erase_events(action)
				InputMap.action_add_event(action, event)
	
	# Video
	display_mode = config.get_value("video", "display_mode", 1)
	resolution = Vector2i(
		config.get_value("video", "resolution_x", 1920),
		config.get_value("video", "resolution_y", 1080)
	)
	vsync_mode = config.get_value("video", "vsync_mode", 1)
	fps_cap = config.get_value("video", "fps_cap", 0)
	fsr_mode = config.get_value("video", "fsr_mode", 0)
	anti_aliasing = config.get_value("video", "anti_aliasing", 2)
	shadow_quality = config.get_value("video", "shadow_quality", 2)
	sdfgi_enabled = config.get_value("video", "sdfgi_enabled", true)
	bloom_enabled = config.get_value("video", "bloom_enabled", true)
	
	apply_video_settings()
	
	# Audio
	master_volume = config.get_value("audio", "master_volume", 1.0)
	sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
	music_volume = config.get_value("audio", "music_volume", 1.0)
	dialog_volume = config.get_value("audio", "dialog_volume", 1.0)
	subtitles_enabled = config.get_value("audio", "subtitles_enabled", true)
	
	apply_audio_settings()

	# Accessibility
	tutorials_enabled = config.get_value("accessibility", "tutorials_enabled", true)

func apply_video_settings():
	# Display Mode
	if display_mode == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif display_mode == 2:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		# Borderless is handled automatically in some OS when using borderless flag, but typically FULLSCREEN acts as borderless in Godot 4 unless exclusive is forced
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_size(resolution)
	
	# VSync & FPS
	DisplayServer.window_set_vsync_mode(vsync_mode as DisplayServer.VSyncMode)
	Engine.max_fps = fps_cap
	
	# Viewport Overrides
	var root = get_viewport()
	
	# FSR
	if fsr_mode == 0:
		root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		root.scaling_3d_scale = 1.0
	else:
		root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 # Godot 4 FSR2
		match fsr_mode:
			1: root.scaling_3d_scale = 0.77 # Quality
			2: root.scaling_3d_scale = 0.67 # Balanced
			3: root.scaling_3d_scale = 0.50 # Performance
			4: root.scaling_3d_scale = 0.33 # Ultra Performance
			
	# Anti-Aliasing
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	root.use_taa = false
	root.msaa_3d = Viewport.MSAA_DISABLED
	
	match anti_aliasing:
		1: root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		2: root.use_taa = true
		3: root.msaa_3d = Viewport.MSAA_2X
		4: root.msaa_3d = Viewport.MSAA_4X
		5: root.msaa_3d = Viewport.MSAA_8X

	# Shadows
	match shadow_quality:
		0: RenderingServer.directional_shadow_atlas_set_size(1024, true)
		1: RenderingServer.directional_shadow_atlas_set_size(2048, true)
		2: RenderingServer.directional_shadow_atlas_set_size(4096, true)
		3: RenderingServer.directional_shadow_atlas_set_size(8192, true)
		
	# Emit signal for world environment to pick up SDFGI and Bloom
	graphics_updated.emit()

func apply_audio_settings():
	var map = {
		"Master": master_volume,
		"SFX": sfx_volume,
		"Music": music_volume,
		"Dialog": dialog_volume
	}
	for bus in map.keys():
		var idx = AudioServer.get_bus_index(bus)
		if idx != -1:
			AudioServer.set_bus_volume_db(idx, linear_to_db(map[bus]))

func apply_preset(preset: int):
	# 0: Ultra, 1: High, 2: Balanced, 3: Performance
	match preset:
		0: # Ultra
			fsr_mode = 0
			anti_aliasing = 4 # MSAA 4x
			shadow_quality = 3 # Ultra
			sdfgi_enabled = true
			bloom_enabled = true
		1: # High
			fsr_mode = 1 # FSR Quality
			anti_aliasing = 2 # TAA
			shadow_quality = 2 # High
			sdfgi_enabled = true
			bloom_enabled = true
		2: # Balanced
			fsr_mode = 2 # FSR Balanced
			anti_aliasing = 2 # TAA
			shadow_quality = 1 # Medium
			sdfgi_enabled = false
			bloom_enabled = true
		3: # Performance
			fsr_mode = 3 # FSR Performance
			anti_aliasing = 1 # FXAA
			shadow_quality = 0 # Low
			sdfgi_enabled = false
			bloom_enabled = false

func apply_and_save():
	apply_video_settings()
	apply_audio_settings()
	save_settings()

func revert_changes():
	load_settings()
