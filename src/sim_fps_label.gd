extends Label

@export var base_text: String

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_simulation_fps_value_changed(value):
	text = base_text + str(value)