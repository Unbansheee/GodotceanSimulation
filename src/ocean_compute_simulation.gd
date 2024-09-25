extends Node
const GOLDEN_RATIO := 1.618033989
const WORK_GROUP_DIM := 32
const UNIFORM_SET := 0

@export_file var shader_input: String
@export_file var initial_shader: String

@export var texture_output: Texture2DRD

@export var simulation_width: int = 256
@export var simulation_height: int = 256

@export var spectrums: Array[SpectrumSettings]

var rd := RenderingServer.get_rendering_device()
var shader_rid: RID
var texture_rds : Array = [ RID(), RID(), RID() ]
var texture_sets : Array = [ RID(), RID(), RID() ]
var pipeline: RID

enum Binding {
	SETTINGS = 0,
	INITIAL_SPECTRUM = 20,
	SPECTRUM = 21,
	PING = 25,
	PONG = 26,
	INPUT = 27,
	OUTPUT = 28,
	DISPLACEMENT = 30,
}

enum FFTResolution {
	FFT_2x2 = 2,
	FFT_4x4 = 4,
	FFT_8x8 = 8,
	FFT_16x16 = 16,
	FFT_32x32 = 32,
	FFT_64x64 = 64,
	FFT_128x128 = 128,
	FFT_256x256 = 256,
	FFT_512x512 = 512,
	FFT_1024x1024 = 1024,
	FFT_2048x2048 = 2048,
}

@export_range(0, 2048) var horizontal_dimension := 256
@export var wave_vector := Vector2(300.0, 0.0)
@export var cascade_ranges:Array[Vector2] = [Vector2(0.0, 0.03), Vector2(0.03, 0.15), Vector2(0.15, 1.0)]
@export var cascade_scales:Array[float] = [GOLDEN_RATIO * 2.0, GOLDEN_RATIO, 0.5]
@export var fft_resolution : FFTResolution
var _fmt_r32f := RDTextureFormat.new()
var _fmt_rg32f := RDTextureFormat.new()
var _fmt_rgba32f := RDTextureFormat.new()

var _initial_spectrum_shader: RID
var _initial_spectrum_pipeline: RID

var _initial_spectrum_settings_buffer_cascade: Array[RID]
var _initial_spectrum_settings_uniform_cascade: Array[RDUniform]
var _initial_spectrum_tex_cascade: Array[RID]
var _initial_spectrum_uniform_cascade: Array[RDUniform]

var _is_initial_spectrum_changed: bool = true

# Called when the node enters the scene tree for the first time.
func _ready():
	RenderingServer.call_on_render_thread(_initialize_simulation)
	RenderingServer.call_on_render_thread(_simulate.bind(0.0))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

	
# Import, compile and load shader, return reference.
func load_shader(device: RenderingDevice, res: Resource) -> RID:
	var shader_spirv: RDShaderSPIRV = res.get_spirv()
	print(shader_spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE))
	var rid = device.shader_create_from_spirv(shader_spirv)
	return rid

func _pack_initial_spectrum_settings(cascade:int) -> PackedByteArray:
	var settings_bytes = PackedInt32Array([fft_resolution, horizontal_dimension * cascade_scales[cascade]]).to_byte_array()
	settings_bytes.append_array(PackedFloat32Array([cascade_ranges[cascade].x, cascade_ranges[cascade].y]).to_byte_array())
	settings_bytes.append_array(PackedVector2Array([wave_vector]).to_byte_array())
	return settings_bytes

func _initialize_simulation():
	var shader_File : Resource
	var settings_bytes : PackedByteArray
	var initial_image_rf := Image.create(int(fft_resolution), int(fft_resolution), false, Image.FORMAT_RF)
	var initial_image_rgf := Image.create(int(fft_resolution), int(fft_resolution), false, Image.FORMAT_RGF)
	
	_fmt_r32f.width = int(fft_resolution)
	_fmt_r32f.height = int(fft_resolution)
	_fmt_r32f.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	_fmt_r32f.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	_fmt_rg32f.width = int(fft_resolution)
	_fmt_rg32f.height = int(fft_resolution)
	_fmt_rg32f.format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT
	_fmt_rg32f.usage_bits = _fmt_r32f.usage_bits
	
	_fmt_rgba32f.width = int(fft_resolution)
	_fmt_rgba32f.height = int(fft_resolution)
	_fmt_rgba32f.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	_fmt_rgba32f.usage_bits = _fmt_r32f.usage_bits
	
	_initial_spectrum_shader = load_shader(rd, ResourceLoader.load(initial_shader))
	_initial_spectrum_pipeline = rd.compute_pipeline_create(_initial_spectrum_shader)
	
	_initial_spectrum_settings_buffer_cascade.resize(cascade_ranges.size())
	_initial_spectrum_settings_uniform_cascade.resize(cascade_ranges.size())
	_initial_spectrum_tex_cascade.resize(cascade_ranges.size())
	_initial_spectrum_uniform_cascade.resize(cascade_ranges.size())

	for i in cascade_ranges.size():
		## Initialize Settings Buffer
		settings_bytes = _pack_initial_spectrum_settings(i)
		_initial_spectrum_settings_buffer_cascade[i] = rd.storage_buffer_create(settings_bytes.size(), settings_bytes)
		_initial_spectrum_settings_uniform_cascade[i] = RDUniform.new()
		_initial_spectrum_settings_uniform_cascade[i].uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		_initial_spectrum_settings_uniform_cascade[i].binding = Binding.SETTINGS
		_initial_spectrum_settings_uniform_cascade[i].add_id(_initial_spectrum_settings_buffer_cascade[i])

		## Initialized empty, it will be generated on the first frame
		_initial_spectrum_tex_cascade[i] = rd.texture_create(_fmt_r32f, RDTextureView.new(), [initial_image_rf.get_data()])
		_initial_spectrum_uniform_cascade[i] = RDUniform.new()
		_initial_spectrum_uniform_cascade[i].uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		_initial_spectrum_uniform_cascade[i].binding = Binding.INITIAL_SPECTRUM
		_initial_spectrum_uniform_cascade[i].add_id(_initial_spectrum_tex_cascade[i])

		
func _simulate(delta: float):
	var uniform_set:RID
	var compute_list:int
	var settings_bytes:PackedByteArray
	
	for cascade in cascade_ranges.size():

		#### Update Initial Spectrum
		########################################################################
		## Only executed on first frame, or if Wind, FFT Resolution, or
		## Horizontal Dimension inputs are changed, as the output is constant
		## for a given set of inputs. The Initial Spectrum is cached in VRAM. It
		## is not returned to CPU RAM.

		if _is_initial_spectrum_changed:
			## Update Settings Buffer
			settings_bytes = _pack_initial_spectrum_settings(cascade)
			if rd.buffer_update(_initial_spectrum_settings_buffer_cascade[cascade], 0, settings_bytes.size(), settings_bytes) != OK:
				print("error updating initial spectrum settings buffer")

			## Build Uniform Set
			uniform_set = rd.uniform_set_create([
			_initial_spectrum_settings_uniform_cascade[cascade],
			_initial_spectrum_uniform_cascade[cascade]], _initial_spectrum_shader, UNIFORM_SET)

			## Create Compute List
			compute_list = rd.compute_list_begin()
			rd.compute_list_bind_compute_pipeline(compute_list, _initial_spectrum_pipeline)
			rd.compute_list_bind_uniform_set(compute_list, uniform_set, UNIFORM_SET)
			@warning_ignore("integer_division")
			rd.compute_list_dispatch(compute_list, int(fft_resolution) / WORK_GROUP_DIM, int(fft_resolution) / WORK_GROUP_DIM, 1)
			rd.compute_list_end()

			## Wait for the compute shader to complete
			rd.barrier(RenderingDevice.BARRIER_MASK_COMPUTE)

			rd.free_rid(uniform_set)
	
	texture_output.set_texture_rd_rid(_initial_spectrum_tex_cascade[0])
