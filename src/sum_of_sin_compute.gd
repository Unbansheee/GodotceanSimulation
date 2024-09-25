extends Node

@export_file var shader_input: String

@export var texture_output: Texture2DRD
var texture_rid: RID
var uniform_set: RID

@export var simulation_width: int = 256
@export var simulation_height: int = 256
@export var group_size := Vector2i(8, 8)

var shader_rid: RID
var pipeline: RID
var rd := RenderingServer.get_rendering_device()

var time: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	setup_pipeline()
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	time += delta;
	execute_compute()
	

func _physics_process(delta: float) -> void:
	pass

func setup_pipeline():
	shader_rid = load_shader(rd, load(shader_input))

	# Create our textures to manage our wave.
	var tf : RDTextureFormat = RDTextureFormat.new()
	tf.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.width = simulation_width
	tf.height = simulation_height
	tf.depth = 1
	tf.array_layers = 1
	tf.mipmaps = 1
	tf.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT + RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT

	# Create our texture.
	texture_rid = rd.texture_create(tf, RDTextureView.new(), [])

	# Make sure our textures are cleared.
	rd.texture_clear(texture_rid, Color(0, 0, 0, 0), 0, 1, 0, 1)

	# Now create our uniform set so we can use these textures in our shader.
	uniform_set = _create_uniform_set(texture_rid)
	texture_output.set_texture_rd_rid(texture_rid)

	print("Created textures and uniform sets.")

	# Create a compute pipeline
	pipeline = rd.compute_pipeline_create(shader_rid)

	

func execute_compute():
	
	var pushConstant: PackedByteArray
	var floats: PackedFloat32Array
	floats.push_back(time);
	var padding: PackedInt32Array
	
	pushConstant.append_array(floats.to_byte_array());

	padding.push_back(1);
	padding.push_back(1);
	padding.push_back(1);
	pushConstant.append_array(padding.to_byte_array());
	
	var x_groups = simulation_width / group_size.x
	var y_groups = simulation_height / group_size.y
	
	# Run our compute shader. 
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)

	rd.compute_list_set_push_constant(compute_list, pushConstant, pushConstant.size())
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()

# Import, compile and load shader, return reference.
func load_shader(device: RenderingDevice, res: Resource) -> RID:
	var shader_spirv: RDShaderSPIRV = res.get_spirv()
	print(shader_spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE))
	var rid = device.shader_create_from_spirv(shader_spirv)
	return rid

	
func _create_uniform_set(texture_rd : RID) -> RID:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(texture_rd)
	# Even though we're using 3 sets, they are identical, so we're kinda cheating.
	return rd.uniform_set_create([uniform], shader_rid, 0)
