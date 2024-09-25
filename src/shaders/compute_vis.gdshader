shader_type spatial;

uniform ivec2 effect_texture_size;
uniform sampler2D effect_texture;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	ALBEDO = texture(effect_texture, UV).xyz;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
