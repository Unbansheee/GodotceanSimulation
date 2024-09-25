extends ComputeBase
class_name ComputeStepButterflyCompute

var pingpong0: RID
var pingpong1: RID
var butterflyTexture: RID

var params_buffer: RID
var params_uniform: RID

var texture_uniforms_01: RID
var texture_uniforms_02: RID

var stages: int;
@export var N: int = 256;

var pingpongval := 0
var stage := 0
var direction := 0

func logWithBase(value, base) -> float: return log(value) / log(base)

func setup():
	stages = logWithBase(N, 2)
	simulation_height = N
	simulation_width = N
	setup_pipeline()
	
	var parambytes = _make_uniform_bytes()
	params_buffer = _create_uniform_buffer(parambytes)

	texture_uniforms_01 = _create_texture_uniform_set([butterflyTexture, pingpong0, pingpong1], 0, 0)
	params_uniform = _create_buffer_uniform_set(params_buffer, 0, 1)
	
	is_ready = true
	
func execute_compute():
	var x_groups = N / 16.0
	var y_groups = N / 16.0

	texture_uniforms_01 = _create_texture_uniform_set([butterflyTexture, pingpong0, pingpong1], 0, 0)

	pingpongval = 0;
	stage = 0;

	for i in range(stages):
		# horizontal
		
		stage = i;
		direction = 0
		
		_update_uniforms()

		var compute_list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, texture_uniforms_01, 0)
		rd.compute_list_bind_uniform_set(compute_list, params_uniform, 1)
		rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
		rd.compute_list_end()

		#rd.barrier(RenderingDevice.BARRIER_MASK_COMPUTE)

		pingpongval += 1;
		pingpongval %= 2;
	
#		
	for j in range(stages):
		# vertical
		stage = j;
		direction = 1
		
		_update_uniforms()

		var compute_list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, texture_uniforms_01, 0)
		rd.compute_list_bind_uniform_set(compute_list, params_uniform, 1)
		rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
		rd.compute_list_end()

		#rd.barrier(RenderingDevice.BARRIER_MASK_COMPUTE)

		pingpongval += 1;
		pingpongval %= 2;
		
		
func _update_uniforms():
	var newparams = _make_uniform_bytes()
	rd.buffer_update(params_buffer, 0, newparams.size(), newparams)

func get_output_texture() -> RID:
	if pingpongval == 0:
		return pingpong0
	elif pingpongval == 1:
		return pingpong1
	return RID()

func get_alternate_texture() -> RID:
	if pingpongval == 0:
		return pingpong1
	elif pingpongval == 1:
		return pingpong0
	return RID()

func _make_uniform_bytes() -> PackedByteArray:
	var arr = PackedInt32Array()
	arr.resize(4)
	arr[0] = stage;
	arr[1] = pingpongval
	arr[2] = direction
	arr[3] = 0
	var newparams: PackedByteArray = arr.to_byte_array()
	return newparams;
