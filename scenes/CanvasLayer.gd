extends CanvasLayer

var last_mouse_pos = Vector2()
var is_mouse_pressed = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var mouse_pos = get_viewport().get_mouse_position()
		var delta_mouse = mouse_pos - last_mouse_pos
		last_mouse_pos = mouse_pos
		offset += delta_mouse
		
	last_mouse_pos = get_viewport().get_mouse_position()

func _input(event: InputEvent) -> void:
	# get mouse position in world coordinates
	var mouse_pos = get_viewport().get_mouse_position()
	mouse_pos = (mouse_pos - offset) / scale
	
	if event.is_action_pressed("zoom_in"):
		scale = scale + Vector2(0.1, 0.1)
		# offset so we zoom on the mouse
		offset = offset - (mouse_pos - offset) * 0.1
	if event.is_action_pressed("zoom_out"):
		scale = scale - Vector2(0.1, 0.1)
		# offset so we zoom on the mouse
		offset = offset + (mouse_pos - offset) * 0.1
		

	
