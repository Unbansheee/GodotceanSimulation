extends Node


@export var shader_input: String

@export var heightmap_height: int = 1024

@export var display_rect: TextureRect

var rd := RenderingServer.get_rendering_device()
var shader_rid: RID
var texture_rds : Array = [ RID(), RID(), RID() ]
var texture_sets : Array = [ RID(), RID(), RID() ]
var pipeline: RID

var mouse_input_uniform_set: RID
var mouse_pos_buffer: RID

var texture : Texture2DRD
var next_texture : int = 0

var simulation_interval : float = 1.0/60.0
var timer: float

var mouse_down: bool = false
var radius: int = 32;

@export var group_size := Vector2i(8, 8)

# Called when the node enters the scene tree for the first time.
func _ready():
	setup_pipeline()
		# Get our texture from our material so we set our RID.
	#var material : ShaderMaterial = display_rect.material as ShaderMaterial
	#if material:
	#	# Set our texture size
	#	print("Setting texture size to: ", heightmap_resolution, heightmap_resolution)
	#	material.set_shader_parameter("effect_texture_size", Vector2i(heightmap_resolution, heightmap_resolution))
#
#		# Get our texture object.
#		texture = material.get_shader_parameter("effect_texture")

	texture = display_rect.texture as Texture2DRD
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	execute_compute()
	#timer += delta
	#while(timer > simulation_interval):
	#	timer = clampf(timer - simulation_interval, 0, simulation_interval)
		
		
func _on_simulation_fps_value_changed(val):
	simulation_interval = 1.0 / val

func _create_uniform_set(texture_rd : RID) -> RID:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(texture_rd)
	# Even though we're using 3 sets, they are identical, so we're kinda cheating.
	return rd.uniform_set_create([uniform], shader_rid, 0)
	
func setup_pipeline():
	shader_rid = load_shader(rd, load(shader_input))
	
	# Create our textures to manage our wave.
	var tf : RDTextureFormat = RDTextureFormat.new()
	tf.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.width = heightmap_height
	tf.height = heightmap_height 
	tf.depth = 1
	tf.array_layers = 1
	tf.mipmaps = 1
	tf.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT + RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT

	for i in range(3):
		# Create our texture.
		texture_rds[i] = rd.texture_create(tf, RDTextureView.new(), [])

		# Make sure our textures are cleared.
		rd.texture_clear(texture_rds[i], Color(0, 0, 0, 0), 0, 1, 0, 1)

		# Now create our uniform set so we can use these textures in our shader.
		texture_sets[i] = _create_uniform_set(texture_rds[i])

	print("Created textures and uniform sets.")
	
	# Create a compute pipeline

	pipeline = rd.compute_pipeline_create(shader_rid)


func _on_timer_timeout():
	pass

# Import, compile and load shader, return reference.
func load_shader(device: RenderingDevice, res: Resource) -> RID:
	var shader_spirv: RDShaderSPIRV = res.get_spirv()
	print(shader_spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE))
	var rid = device.shader_create_from_spirv(shader_spirv)
	return rid

func execute_compute():
	next_texture = (next_texture + 1) % 3
	if texture:
		texture.texture_rd_rid = texture_rds[next_texture]
	# Submit to GPU and wait for sync
	var next_set = texture_sets[next_texture]
	var current_set = texture_sets[(next_texture - 1) % 3]
	var previous_set = texture_sets[(next_texture - 2) % 3]

	var mouse_pos: Vector2i;
	if mouse_down:
		mouse_pos = display_rect.get_local_mouse_position()
		# scale mouse position to texture size
		mouse_pos.x = mouse_pos.x / display_rect.size.x * heightmap_height
		mouse_pos.y = mouse_pos.y / display_rect.size.y * heightmap_height
	else:
		mouse_pos = Vector2i(-10, -10)
		
	var mouse_pos_array := PackedInt32Array()
	mouse_pos_array.resize(4)
	mouse_pos_array[0] = int(mouse_pos.x)
	mouse_pos_array[1] = int(mouse_pos.y)
	mouse_pos_array[2] = radius
	
	var bytes = mouse_pos_array.to_byte_array()
	#rd.buffer_update(mouse_pos_buffer, 0, 12, mouse_pos_array.to_byte_array())

	var x_groups = heightmap_height / group_size.x
	var y_groups = heightmap_height / group_size.y


	# Run our compute shader. 
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, current_set, 0)
	rd.compute_list_bind_uniform_set(compute_list, previous_set, 1)
	rd.compute_list_bind_uniform_set(compute_list, next_set, 2)

	rd.compute_list_set_push_constant(compute_list, bytes, bytes.size())
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()

func _on_draw_radius_value_changed(val):
	radius = val

func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mouse_event = event as InputEventMouseButton
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				if mouse_event.pressed:
					mouse_down = true
				else:
					mouse_down = false
