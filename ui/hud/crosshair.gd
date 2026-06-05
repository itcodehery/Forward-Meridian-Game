extends Control

@onready var reticle = $ReticleImage 
var reticle_overlay: TextureRect # Auto-generated for fading

var data: CrosshairData = null
var current_state: String = "normal"

# Current animated values
var current_scale: float = 1.0
var target_scale: float = 1.0
var recoil_bump: float = 0.0

# Texture swap logic
var is_firing: bool = false
var firing_timer: float = 0.0
const FIRING_DISPLAY_TIME: float = 0.1 

# --- NEW: Fading Logic ---
var current_displayed_texture: Texture2D = null
var fade_tween: Tween
const FADE_SPEED: float = 0.1 # Adjust this to make the crossfade faster/slower

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	# Auto-create the overlay so you don't have to edit the UI scene
	if reticle:
		reticle_overlay = reticle.duplicate()
		add_child(reticle_overlay)
		reticle_overlay.modulate.a = 0.0 # Hide it initially
	
	await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("players")
	if player and player.weapon_handler:
		player.crosshair_state_changed.connect(_on_state_changed)
		player.weapon_handler.crosshair_updated.connect(_on_crosshair_updated)
		player.weapon_handler.weapon_fired.connect(_on_weapon_fired)
		
		var current_data = player.weapon_handler.get_current_data()
		if current_data and current_data.crosshair:
			_on_crosshair_updated(current_data.crosshair)

func _on_crosshair_updated(new_data: CrosshairData):
	data = new_data
	if reticle and data:
		reticle.texture = data.tex_normal
		current_displayed_texture = data.tex_normal
		reticle.visible = true 
	_calculate_targets()

func _on_state_changed(state: String):
	current_state = state
	_calculate_targets()

func _on_weapon_fired():
	if data:
		recoil_bump += data.shoot_scale_bump
		is_firing = true
		firing_timer = FIRING_DISPLAY_TIME

func _calculate_targets():
	if not data: return
	match current_state:
		"ads": target_scale = data.base_scale 
		"sprint": target_scale = data.base_scale * data.sprint_scale_mult
		"crouch": target_scale = data.base_scale * data.crouch_scale_mult
		_: target_scale = data.base_scale

func _process(delta):
	if not data or not reticle or not reticle_overlay: return
	
	var is_aiming = (current_state == "ads")
	var target_texture: Texture2D = null
	
	# 1. Determine the TARGET Texture (What should we be looking at?)
	if is_firing:
		firing_timer -= delta
		if is_aiming:
			target_texture = data.tex_ads_active if data.tex_ads_active else data.tex_ads
		else:
			target_texture = data.tex_active if data.tex_active else data.tex_normal
		
		if firing_timer <= 0:
			is_firing = false
	else:
		if is_aiming:
			target_texture = data.tex_ads if data.tex_ads else data.tex_normal
		else:
			target_texture = data.tex_normal

	# 2. Trigger Crossfade if the target changed
	_update_texture(target_texture)

	# 3. Smooth Scale Animation
	recoil_bump = lerp(recoil_bump, 0.0, data.recovery_speed * delta)
	current_scale = lerp(current_scale, target_scale + recoil_bump, data.lerp_speed * delta)
	
	# 4. Apply Scale to BOTH images
	var new_scale = Vector2(current_scale, current_scale)
	reticle.scale = new_scale
	reticle_overlay.scale = new_scale
	
	# 5. Center BOTH images
	var center_pos = global_position - (reticle.size * reticle.scale / 2.0)
	reticle.global_position = center_pos
	reticle_overlay.global_position = center_pos

# --- NEW: The Crossfade Engine ---
func _update_texture(new_tex: Texture2D):
	if new_tex == current_displayed_texture:
		return # Do nothing if we are already showing (or fading to) this texture
		
	current_displayed_texture = new_tex
	
	# Kill any existing fade animation so they don't overlap/glitch
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
		
	# Setup the new crossfade
	reticle_overlay.texture = new_tex
	reticle_overlay.modulate.a = 0.0
	
	fade_tween = create_tween().set_parallel(true)
	
	# Fade main OUT, Fade overlay IN simultaneously
	fade_tween.tween_property(reticle, "modulate:a", 0.0, FADE_SPEED)
	fade_tween.tween_property(reticle_overlay, "modulate:a", 1.0, FADE_SPEED)
	
	# Once the fade completes, swap them secretly so we are ready for the next one
	fade_tween.chain().tween_callback(func():
		reticle.texture = new_tex
		reticle.modulate.a = 1.0
		reticle_overlay.modulate.a = 0.0
	)
