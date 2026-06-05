extends CanvasLayer

@onready var main_container = $Control
@onready var texture_rect = $Control/TextureRect
@onready var progress_bar = $Control/TextureProgressBar
@onready var anim = $Control/AnimationPlayer
#@onready var main_container = $SubViewportContainer/SubViewport/Control
#@onready var texture_rect = $SubViewportContainer/SubViewport/Control/TextureRect
#@onready var progress_bar = $SubViewportContainer/SubViewport/Control/TextureProgressBar
#@onready var anim = $SubViewportContainer/SubViewport/Control/AnimationPlayer

var hold_time: float = 0.0
var is_active: bool = false

@export var HOLD_REQUIREMENT: float = 3.0  # Now editable in the Inspector

var tutorial_data = {
	"intro": "res://assets/ui/tutorials/tutorial-intro.png",
	"equipment": "res://assets/ui/tutorials/tutorial-equipment.png",
}

func _ready():
	main_container.hide()
	set_process(false)
	progress_bar.max_value = HOLD_REQUIREMENT  # Set once on ready
	progress_bar.value = 0

func start_tutorial(tutorial_key: String):
	if not tutorial_data.has(tutorial_key):
		push_error("Tutorial key not found: " + tutorial_key)
		return

	texture_rect.texture = load(tutorial_data[tutorial_key])
	hold_time = 0.0
	progress_bar.max_value = HOLD_REQUIREMENT  # Sync in case Inspector value changed
	progress_bar.value = 0

	main_container.show()
	get_tree().call_group("ui", "hide")
	anim.play("fade_in")

	is_active = true
	set_process(true)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta):
	if is_active:
		if Input.is_action_pressed("interact"):
			hold_time += delta
			progress_bar.value = hold_time  # Direct assignment — max_value handles the range

			if hold_time >= HOLD_REQUIREMENT:
				finish_tutorial()
		else:
			hold_time = move_toward(hold_time, 0.0, delta * 2.0)
			progress_bar.value = hold_time  # Same here

func finish_tutorial():
	is_active = false
	set_process(false)

	anim.play_backwards("fade_in")
	await anim.animation_finished
	main_container.hide()

	get_tree().paused = false
	get_tree().call_group("ui", "show")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
