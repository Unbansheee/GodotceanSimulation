extends ComputeBase
class_name ComputeStepInversionPermutation

var displacementTexture: RID
var height: RID
var choppy: RID

var pingPong: int
@export var N: int

var params_buffer: RID
var params_uniform: RID
var texture_uniforms: RID

func setup():
	simulation_height = N
	simulation_width = N
	
	setup_pipeline()
	var params: PackedInt32Array
	params.resize(4)
	params[0] = pingPong
	params[1] = N
	var bytes = params.to_byte_array()
	
	displacementTexture = _create_sim_texture()	

	texture_uniforms = _create_texture_uniform_set([displacementTexture, height, choppy], 0, 0)	

	params_buffer = _create_uniform_buffer(bytes)
	params_uniform = _create_buffer_uniform_set(params_buffer, 0, 1)
	
	is_ready = true


func execute_compute():
	var x_groups = N / 16.0
	var y_groups = N / 16.0
	

	var params: PackedInt32Array
	params.resize(4)
	params[0] = pingPong
	params[1] = N
	var bytes = params.to_byte_array()
	
	
	rd.buffer_update(params_buffer, 0, bytes.size(), bytes)
	texture_uniforms = _create_texture_uniform_set([displacementTexture, height, choppy], 0, 0)	
	
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	
	rd.compute_list_bind_uniform_set(compute_list, texture_uniforms, 0)
	rd.compute_list_bind_uniform_set(compute_list, params_uniform, 1)
	
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()
