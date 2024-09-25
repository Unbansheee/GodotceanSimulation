class_name Complex

var real: float
var imag: float

func _init(_real: float, _imag: float):
	real = _real
	imag = _imag
	
func conj(other: Complex) -> Complex:
	return Complex.new(real, -imag)
	
func mult(other: Complex) -> Complex:
	return Complex.new(real * other.real - imag * other.imag, real * other.imag + imag * other.real)
	
func add(other: Complex) -> Complex:
	return Complex.new(real + other.real, imag + other.imag)

func to_bytes() -> PackedByteArray:
	var bytes: PackedByteArray
	bytes.resize(8)
	bytes.encode_float(0, real)
	bytes.encode_float(4, imag)
	return bytes
	
func to_bytes_padded() -> PackedByteArray:
	var bytes: PackedByteArray
	bytes.resize(16)
	bytes.encode_float(0, real)
	bytes.encode_float(4, imag)
	return bytes
