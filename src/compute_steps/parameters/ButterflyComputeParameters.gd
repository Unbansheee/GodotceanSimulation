extends Resource
class_name ButterflyComputeParameters

@export var stage: int;
@export var pingpongval: int;
@export var direction: int;
@export var N: int
@export var count: int;

func to_byte_array() -> PackedByteArray:
	var arr = PackedInt32Array()
	arr.resize(4)
	arr[0] = stage;
	arr[1] = pingpongval
	arr[2] = direction
	arr[3] = 0
	return arr.to_byte_array()
