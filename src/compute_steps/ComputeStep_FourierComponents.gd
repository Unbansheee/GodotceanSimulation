extends ComputeBase
class_name ComputeStepFourierComponents

var h0kTex: RID
var frequencies: RID

var hktdyTex: RID
var hktDTex : RID

var textureUniforms: RID
var paramsUniforms: RID

var uniform_buffer: RID

@export var params: FourierComponentsParameters

# Called when the node enters the scene tree for the first time.
func _ready():
	pass
	
func setup():
	setup_pipeline()
	simulation_height = params.N
	simulation_width = params.N
	uniform_buffer = _create_uniform_buffer(params.to_byte_array())
	
	hktdyTex = _create_sim_texture()
	hktDTex = _create_sim_texture()
	textureUniforms = _create_texture_uniform_set([hktdyTex, hktDTex, h0kTex, frequencies], 0, 0)
	paramsUniforms = _create_buffer_uniform_set(uniform_buffer, 0, 1)
	is_ready = true
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	super._process(delta)

func execute_compute():
	var x_groups = params.N/16
	var y_groups = params.N/16
	
	var pc: PackedByteArray
	pc.resize(16)
	pc.encode_float(0,time)

	
	
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, textureUniforms, 0)
	rd.compute_list_bind_uniform_set(compute_list, paramsUniforms, 1)
	rd.compute_list_set_push_constant(compute_list, pc, pc.size())
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()
