extends Node

@export var N: int = 256
@export var L: int = 2000
@export var A: int = 4
@export var Wind: Vector2

@export var GenerateSpectrum: ComputeStepGenerateSpectrum
@export var FourierComponents: ComputeStepFourierComponents
@export var ButterflyComputeHoriz: ComputeStepButterflyCompute
@export var InversionPermutation: ComputeStepInversionPermutation
@export var CreateGradients: ComputeStepCreateGradients

@export var ButterflyTexture: ComputeStepButterflyTexture

@export var displacement_output: Texture2DRD
@export var spectrum_initial_output: Texture2DRD
@export var butterfly_tex_output: Texture2DRD
@export var spectrum_evolution_output: Texture2DRD
@export var spectrum_evolution_output_chop: Texture2DRD
@export var gradient_output: Texture2DRD



var timer : float

var t: float
var sys_time: float = current_time_ms()
var t_delta: float = 1.0/1000.0;

var timerCounter: TimerCounter = TimerCounter.new()

var pingpong_texture: RID
var pingpong_texture_b: RID

var rd := RenderingServer.get_rendering_device()

# Called when the node enters the scene tree for the first time.
func _ready():
	await get_tree().process_frame
	timerCounter.scale = 10;
	timerCounter.start()
	GenerateSpectrum.params.N = N
	GenerateSpectrum.params.L = L
	GenerateSpectrum.params.WindDirection = Wind
	GenerateSpectrum.params.A = A
	GenerateSpectrum.setup()
	GenerateSpectrum.execute_compute()
	
	FourierComponents.h0kTex = GenerateSpectrum.h0kTex
	FourierComponents.frequencies = GenerateSpectrum.waveDataTexture
	FourierComponents.params.L = L
	FourierComponents.params.N = N
	FourierComponents.setup()
	
	#var ButterFlyTextureCS = ButterflyTexture as ButterflyGeneratorSharp
	#ButterFlyTextureCS.N = N
	#ButterFlyTextureCS.Setup()
	#ButterFlyTextureCS.Execute()
	ButterflyTexture.N = N
	ButterflyTexture.setup()
	ButterflyTexture.execute_compute()

	ButterflyComputeHoriz.N = N
	pingpong_texture = ButterflyComputeHoriz.create_sim_texture(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT, N, N)
	pingpong_texture_b = ButterflyComputeHoriz.create_sim_texture(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT, N, N)

	ButterflyComputeHoriz.pingpong0 = FourierComponents.hktdyTex
	ButterflyComputeHoriz.pingpong1 = pingpong_texture
	ButterflyComputeHoriz.butterflyTexture = ButterflyTexture.butterflyTex
	ButterflyComputeHoriz.setup()

	InversionPermutation.N = N
	InversionPermutation.height = FourierComponents.hktdyTex
	InversionPermutation.choppy = FourierComponents.hktDTex
	InversionPermutation.setup()
	
	CreateGradients.N = N
	CreateGradients.L = L
	CreateGradients.displacementTexture = InversionPermutation.displacementTexture
	CreateGradients.setup()

	displacement_output.set_texture_rd_rid(InversionPermutation.displacementTexture)
	butterfly_tex_output.set_texture_rd_rid(ButterflyTexture.butterflyTex)
	spectrum_initial_output.set_texture_rd_rid(GenerateSpectrum.h0kTex)
	spectrum_evolution_output.set_texture_rd_rid(FourierComponents.hktdyTex)
	spectrum_evolution_output_chop.set_texture_rd_rid(FourierComponents.hktDTex)
	gradient_output.set_texture_rd_rid(CreateGradients.gradients)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	timer += delta
	if timer >= 1.0/60.0:
		timer = 0
		compute()
		t += (current_time_ms() - sys_time) * t_delta
		sys_time = current_time_ms()

func compute():
	var time: float = timerCounter.update()
	if FourierComponents.is_ready:
		timerCounter.update()
		FourierComponents.time = Time.get_ticks_msec()
		FourierComponents.execute_compute()
	
	var height: RID
	var choppy: RID
	
	if (ButterflyComputeHoriz.is_ready):
		ButterflyComputeHoriz.butterflyTexture = ButterflyTexture.butterflyTex
		ButterflyComputeHoriz.pingpongval = 0
		ButterflyComputeHoriz.pingpong0 = FourierComponents.hktdyTex
		ButterflyComputeHoriz.pingpong1 = pingpong_texture
		ButterflyComputeHoriz.execute_compute()
		height = ButterflyComputeHoriz.get_output_texture()
		
	if (ButterflyComputeHoriz.is_ready):
		ButterflyComputeHoriz.pingpongval = 0
		ButterflyComputeHoriz.pingpong0 = FourierComponents.hktDTex
		ButterflyComputeHoriz.pingpong1 = pingpong_texture_b
		ButterflyComputeHoriz.execute_compute()
		choppy = ButterflyComputeHoriz.get_output_texture()


	if (InversionPermutation.is_ready):
		InversionPermutation.pingPong = ButterflyComputeHoriz.pingpongval
		InversionPermutation.height = height
		InversionPermutation.choppy = choppy
		InversionPermutation.execute_compute()
		
	if (CreateGradients.is_ready):
		CreateGradients.displacementTexture = InversionPermutation.displacementTexture
		CreateGradients.execute_compute()
	
	
func current_time_ms() -> float:
	return Time.get_unix_time_from_system() * 1000.0


