class_name ComputeStepGenerateSpectrum
extends ComputeBase

var h0kTex: RID
var waveDataTexture: RID

var h0minuskTex: RID

var h0kUniforms: RID
var noiseUniforms: RID
var paramsUniforms: RID

var uniform_buffer: RID

@export var spec_tex: Texture2DRD
@export var noise_maps: Array[Texture2D]
@export var params: SpectrumComputeParameters


# Called when the node enters the scene tree for the first time.
func _ready():
	pass
	

func setup():
	var start = params.N / 2
	
	var h0data : Array[Complex]
	h0data.resize((params.N + 1) * (params.N + 1))
	var wdata : PackedFloat32Array
	wdata.resize((params.N+1) * (params.N+1))
	
	
	var w := params.WindDirection.normalized()
	var V := params.WindDirection.length()
	var A := params.A
	var k: Vector2;
	var L = params.L;
	
	var rng = RandomNumberGenerator.new()
	
	for m in range(params.N):
		k.y = ((PI*2) * (start - m)) / L
		
		for n in range(params.N):
			k.x = ((PI*2) * (start - n)) / L
			var index: int = m * (params.N + 1) + n
			var sqrt_P_h = 0
			if k.x != 0.0 or k.y != 0.0:
				sqrt_P_h = sqrt(phillips(k, w, V, A))
				
			var h0 := Complex.new((sqrt_P_h * rng.randfn(0.0, 1.0) * (1/sqrt(2))), (sqrt_P_h * rng.randfn(0.0, 1.0) * (1/sqrt(2))))
			h0data[index] = h0
			
			wdata[index] = sqrt(9.81 * k.length())
	
	waveDataTexture = create_sim_texture(RenderingDevice.DATA_FORMAT_R32_SFLOAT, params.N+1, params.N+1)
	h0kTex = create_sim_texture(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT, params.N+1, params.N+1)
	
	rd.texture_update(waveDataTexture, 0, wdata.to_byte_array())
	
	var bytes: PackedFloat32Array
	bytes.resize((params.N+1) * (params.N+1) * 4)
	var idx := 0
	for h in range(h0data.size()):
		if (!h0data[h]):
			h0data[h] = Complex.new(0, 0)
		bytes[idx] = h0data[h].real
		bytes[idx + 1] = h0data[h].imag
		bytes[idx + 2] = 0.0
		bytes[idx + 3] = 1.0
		idx += 4
	
	rd.texture_update(h0kTex, 0, bytes.to_byte_array())
	
	
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	super._process(delta)

func execute_compute():
	pass


func _create_sim_noise_from_texture(texture: Texture2D) -> RID:
	var img: Image = texture.get_image()
	var texID: RID;
	var tf : RDTextureFormat = RDTextureFormat.new()
	tf.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.width = img.get_width()
	tf.height = img.get_height()
	tf.depth = 1;
	tf.array_layers = 1
	tf.mipmaps = 1
	tf.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	texID = rd.texture_create(tf, RDTextureView.new(), [img.get_data()])
	
	return texID


func phillips(k: Vector2, w: Vector2, V: float, A: float):
	var L: float = (V*V) / 9.81
	var l: float = L/1000.0
	var kdotw: float = k.dot(w)
	var k2: float = k.dot(k)
	
	var P_h = A * (exp(-1.0 / (k2 * L * L))) / (k2*k2*k2) * (kdotw * kdotw)
	
	if (kdotw < 0.0):
		P_h *= 0.07
		
	return P_h * exp(-k2 * l * l)
