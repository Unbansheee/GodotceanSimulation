class_name ComputeBase
extends Node

var rd:RenderingDevice = RenderingServer.get_rendering_device()

@export_file var shader_input: String

@export var simulation_width: int = 256
@export var simulation_height: int = 256
@export var group_size := Vector2i(8, 8)

var shader_rid: RID
var pipeline: RID

var time: float = 0.0
var is_ready: bool = false

# Import, compile and load shader, return reference.
func load_shader(device: RenderingDevice, res: Resource) -> RID:
	var shader_spirv: RDShaderSPIRV = res.get_spirv()
	print(shader_spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE))
	var rid = device.shader_create_from_spirv(shader_spirv)
	return rid


func _create_texture_uniform_set(texture_rd : Array[RID], binding: int, set_id: int, type: int = RenderingDevice.UNIFORM_TYPE_IMAGE) -> RID:
	var uniforms: Array[RDUniform]
	var index: int = 0
	for texture in texture_rd:
		var uniform := RDUniform.new()
		uniform.uniform_type = type
		uniform.binding = binding + index
		uniform.add_id(texture)
		uniforms.push_back(uniform)
		index += 1;
	return rd.uniform_set_create(uniforms, shader_rid, set_id)

func _create_sampler_uniform_set(texture_rd : Array[RID], binding: int, set_id: int) -> RID:
	var uniforms: Array[RDUniform]
	var index: int = 0
	for texture in texture_rd:
		var uniform := RDUniform.new()
		var samp_state: RDSamplerState = RDSamplerState.new()
		samp_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
		samp_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
		samp_state.mip_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
		var samp = rd.sampler_create(samp_state)
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		uniform.binding = binding + index
		uniform.add_id(samp)
		uniform.add_id(texture)
		
		uniforms.push_back(uniform)
		index += 1;
	return rd.uniform_set_create(uniforms, shader_rid, set_id)

func _create_buffer_uniform_set(buffer : RID, binding: int, set_id: int) -> RID:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	uniform.binding = binding
	uniform.add_id(buffer)
	return rd.uniform_set_create([uniform], shader_rid, set_id)

func _create_storage_buffer_set(buffer : RID, binding: int, set_id: int) -> RID:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = binding
	uniform.add_id(buffer)
	return rd.uniform_set_create([uniform], shader_rid, set_id)	

func create_sim_texture(fmt: int = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT, w: int = simulation_width, h: int = simulation_height) -> RID:	
	return _create_sim_texture(fmt, w, h)

func _create_sim_texture(fmt: int = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT, w: int = simulation_width, h: int = simulation_height) -> RID:
	var texID: RID;
	var tf : RDTextureFormat = RDTextureFormat.new()
	tf.format = fmt
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.width = w
	tf.height = h
	tf.depth = 1
	tf.array_layers = 1
	tf.mipmaps = 1
	tf.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT + RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	
	# Create our texture.
	texID = rd.texture_create(tf, RDTextureView.new(), [])

	# Make sure our textures are cleared.
	rd.texture_clear(texID, Color(0, 0, 0, 0), 0, 1, 0, 1)
	return texID;

func _create_uniform_buffer(buff: PackedByteArray) -> RID:
	var id: RID
	id = rd.uniform_buffer_create(buff.size(), buff)
	return id

func _create_storage_buffer(buff: PackedByteArray) -> RID:
	var id: RID
	id = rd.storage_buffer_create(buff.size(), buff)
	return id

func setup_pipeline():
	shader_rid = load_shader(rd, load(shader_input))
	pipeline = rd.compute_pipeline_create(shader_rid)

func _process(delta: float) -> void:
	pass
	
func execute_compute():
	pass

func _tex_array_to_rid(noises: Array[Texture]) -> Array[RID]:
	var arr: Array[RID]
	for noise in noises:
		arr.push_back(noise.get_rid())
	return arr

func _noise_tex_array_to_rid(noises: Array[NoiseTexture2D]) -> Array[RID]:
	var arr: Array[RID]
	for noise in noises:
		arr.push_back(noise.get_rid())
	return arr

func setup():
	pass
