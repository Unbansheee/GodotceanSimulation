extends Resource
class_name FourierComponentsParameters

@export var N: int;
@export var L: int;

func to_byte_array() -> PackedByteArray:
	var packed = PackedByteArray()
	packed.resize(16)
	packed.encode_s32(0, N)
	packed.encode_s32(4, L)
	return packed