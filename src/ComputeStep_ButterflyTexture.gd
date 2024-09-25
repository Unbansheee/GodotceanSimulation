extends ComputeBase
class_name ComputeStepButterflyTexture

var butterflyTex: RID
var texture_uniforms: RID

var indices_buffer: RID
var indices: PackedInt32Array
var indices_uniform: RID

var uniform_buffer: RID
var paramsUniform: RID
@export var N: int;

func setup():
	setup_pipeline()
	
	simulation_width = log(N) / log(2)	
	simulation_height = N;

	butterflyTex = _create_sim_texture()
	texture_uniforms = _create_texture_uniform_set([butterflyTex], 0, 0)
	
	indices = initBitReversedIndices()
	indices_buffer = _create_storage_buffer(indices.to_byte_array())
	indices_uniform = _create_storage_buffer_set(indices_buffer, 0, 1)

	var uniforms: PackedByteArray
	uniforms.resize(16)
	uniforms.encode_s32(0, N)
	uniform_buffer = _create_uniform_buffer(uniforms)
	paramsUniform = _create_buffer_uniform_set(uniform_buffer, 0, 2)
	is_ready = true

func execute_compute():
	var x_groups = simulation_width / group_size.x
	var y_groups = simulation_height / group_size.y
	x_groups = log(N) / log(2)
	y_groups = N / 16
	
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, texture_uniforms, 0)
	rd.compute_list_bind_uniform_set(compute_list, indices_uniform, 1)
	rd.compute_list_bind_uniform_set(compute_list, paramsUniform, 2)
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()

func initBitReversedIndices() -> PackedInt32Array:
	var bitReversedIndices: PackedInt32Array = PackedInt32Array()
	bitReversedIndices.resize(N)
	var bits: int = log(N) / log(2)
	
	for i in range(N):
		var rev: int     = reverse_bits_32(i)
		var rotated: int = rotate_left_32(rev, bits)
		bitReversedIndices.set(i, rotated)
		
	return bitReversedIndices

func rotate_left_32(value:int, shift_amount:int)->int:
	var mask: int   = 0xFFFFFFFF # This is the mask for 32 bits
	var result: int = (value << shift_amount) & mask # Perform the rotation
	result |= (value >> (32 - shift_amount)) & mask # Wrap around the shifted bits
	return result

func reverse_bits_32(value: int)->int:
	var mask: int     = 0xFFFFFFFF # Mask for 32 bits
	var reversed: int = 0
	for i in range(32): # Loop through each bit
		reversed = (reversed << 1) | (value & 1) # Add the least significant bit of value to reversed
		value >>= 1 # Shift value to get the next bit
	return reversed & mask # Apply mask to get only the lower 32 bits
