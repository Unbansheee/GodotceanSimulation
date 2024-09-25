extends ComputeBase
class_name ComputeStepCreateGradients

var displacementTexture: RID
var gradients: RID

@export var N: int = 256
@export var L: int = 2000

var texture_uniforms: RID


func setup():
	simulation_height = N
	simulation_width = N

	setup_pipeline()

	gradients = _create_sim_texture(RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
	texture_uniforms = _create_texture_uniform_set([displacementTexture, gradients], 0, 0)	
	
	is_ready = true


func execute_compute():
	var pc: PackedInt32Array
	pc.resize(4)
	pc[0] = N;
	pc[1] = L
	
	var x_groups = N / 16.0
	var y_groups = N / 16.0
	
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_set_push_constant(compute_list, pc.to_byte_array(), pc.to_byte_array().size())
	rd.compute_list_bind_uniform_set(compute_list, texture_uniforms, 0)
	
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()
