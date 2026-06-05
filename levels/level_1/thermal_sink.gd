extends Area3D

@export var damage_per_tick: float = 15.0 # How much health it eats
@export var tick_rate: float = 0.5 # How often it bites
@export var damage_audio: AudioStream
@export var fade_duration: float = 1.0 # How long the fade out takes

@onready var audio_player = $AudioStreamPlayer3D
@onready var damage_timer = $Timer

var players_in_zone = []
var audio_tween: Tween # Keeps track of the fade animation

func _ready():
	damage_timer.wait_time = tick_rate
	damage_timer.timeout.connect(_on_timer_timeout)
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("players"):
		players_in_zone.append(body)
		
		# Start the "burn" timer
		if damage_timer.is_stopped():
			damage_timer.start()
			
		# If this is the first player entering, start the audio
		if players_in_zone.size() == 1:
			_start_sizzle_audio()

func _on_body_exited(body):
	if body in players_in_zone:
		players_in_zone.erase(body)
		
		# If the last player escaped, stop the timer and fade the audio!
		if players_in_zone.is_empty():
			damage_timer.stop()
			_fade_out_audio()

func _on_timer_timeout():
	# Only handle damage here now, audio is handled by enter/exit
	for player in players_in_zone:
		if player.has_method("take_damage"):
			player.take_damage(damage_per_tick)

func _start_sizzle_audio():
	if not damage_audio: return
	
	# If the player re-enters while it's still fading out, kill the fade
	if audio_tween and audio_tween.is_valid():
		audio_tween.kill()
		
	audio_player.stream = damage_audio
	audio_player.volume_db = 0.0 # Reset volume back to normal!
	
	if not audio_player.playing:
		audio_player.pitch_scale = randf_range(0.9, 1.1)
		audio_player.play()

func _fade_out_audio():
	if not audio_player.playing: return
	
	# Create a new tween to smoothly drop the volume to -80dB (silent)
	audio_tween = create_tween()
	audio_tween.tween_property(audio_player, "volume_db", -80.0, fade_duration)
	
	# Once the fade is done, actually stop the player so it's not playing silently
	audio_tween.tween_callback(audio_player.stop)
