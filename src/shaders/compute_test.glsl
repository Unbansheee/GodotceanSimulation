#[compute]
#version 460

// Invocations in the (x, y, z) dimension
layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

// Our textures.
layout(r32f, set = 0, binding = 0) uniform restrict readonly image2D current_heightmap;
layout(r32f, set = 1, binding = 0) uniform restrict readonly image2D previous_heightmap;
layout(r32f, set = 2, binding = 0) uniform restrict writeonly image2D output_heightmap;

// mouse position in screen space
layout(push_constant) uniform Mouse {
	ivec2 mouse_pos; // 8 bytes
	int draw_radius; // 4 bytes // =12 bytes
	int padding[1];

} PushConstant;




void get_neighbour_coords(out ivec2[8] neighbour_coords, in ivec2 coords) {
	// Return the eight neighbour indices of the given index.
	// Don't worry about whether the indices are out of bounds.
	neighbour_coords = ivec2[8](
		coords + ivec2(0, 1),
		coords + ivec2(1, 0),
		coords + ivec2(0, -1),
		coords + ivec2(-1, 0),
		coords + ivec2(1, 1),
		coords + ivec2(1, -1),
		coords + ivec2(-1, -1),
		coords + ivec2(-1, 1)
	);
}

// The code we want to execute in each invocation
void main() {
	// gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
	//set heightmap pixel to random value
	ivec2 coords = ivec2(gl_GlobalInvocationID.xy);

	ivec2[8] neightbour_coords;
	get_neighbour_coords(neightbour_coords, coords);
	
	float neightbour_life_sum = 0.0;
	for (int i = 0; i < 8; i++) {
		neightbour_life_sum += imageLoad(current_heightmap, neightbour_coords[i]).r;
	}
	
	float life = float((neightbour_life_sum == 2.0)) * imageLoad(current_heightmap, coords).r + float((neightbour_life_sum == 3.0)) * 1.0;
	ivec2 mouse_pos = PushConstant.mouse_pos;
	int draw_radius = PushConstant.draw_radius;
	if (mouse_pos.x > 0 && mouse_pos.y > 0)
	{
		ivec2 vec = coords - mouse_pos;
		float distance = length(vec);
		//get mouse pos from push constant
		if (distance <= draw_radius) {
			life = 1.0;
		}
	}
	
	
	imageStore(output_heightmap, coords, vec4(life));
	
}
