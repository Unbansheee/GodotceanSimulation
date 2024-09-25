extends Resource
class_name SpectrumComputeParameters

@export var N: int
@export var L: int
@export var A: float
@export var WindDirection: Vector2
@export var WindSpeed: float

func to_byte_array() -> PackedByteArray:
	var bytes: PackedByteArray
	bytes.resize(32)
	bytes.encode_s32(0, N) 	
	bytes.encode_s32(4, L) 
	bytes.encode_float(8, A)
	bytes.encode_float(12, WindDirection.x)
	bytes.encode_float(16, WindDirection.y)
	
	
	return bytes