extends Camera2D

var last_mouse_pos = Vector2()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var mouse_pos = get_global_mouse_position()
		var delta_mouse = last_mouse_pos - mouse_pos
		last_mouse_pos = mouse_pos
		offset += delta_mouse
	
	last_mouse_pos = get_global_mouse_position()

	
func _input(event: InputEvent):
	#checkforscroll
	if event.is_action_pressed("zoom_in"):
		#scroll up
		zoom += (zoom * Vector2(0.02,0.02))
	elif event.is_action_pressed("zoom_out"):
		#scroll down
		zoom -= (zoom * Vector2(0.02,0.02))
