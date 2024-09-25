#[compute]
#version 460 core

layout(local_size_x = 16, local_size_y = 16) in;

layout(binding = 0, rgba32f) readonly uniform image2D displacement;
layout(binding = 1, rgba16f) writeonly uniform image2D gradients;

layout(push_constant) uniform PushConstant
{
        int N;
        int L;
} pc;
        

void main() {
        float normal_factor = 1.0;
        ivec2 loc = ivec2(gl_GlobalInvocationID.xy);

        ivec2 left			= (loc - ivec2(1, 0)) & (pc.N - 1);
        ivec2 right			= (loc + ivec2(1, 0)) & (pc.N - 1);
        ivec2 bottom		= (loc - ivec2(0, 1)) & (pc.N - 1);
        ivec2 top			= (loc + ivec2(0, 1)) & (pc.N - 1);
        
        vec3 disp_left		= imageLoad(displacement, left).xyz;
        vec3 disp_right		= imageLoad(displacement, right).xyz;
        vec3 disp_bottom	= imageLoad(displacement, bottom).xyz;
        vec3 disp_top		= imageLoad(displacement, top).xyz;
        
        vec2 gradient		= vec2(disp_left.y - disp_right.y, disp_bottom.y - disp_top.y);

        float INV_TILE_SIZE = pc.N / pc.L;
        float TILE_SIZE_X2 = (pc.L * 2.0) / pc.N;
        
        // Jacobian
        vec2 dDx = (disp_right.xz - disp_left.xz) * INV_TILE_SIZE;
        vec2 dDy = (disp_top.xz - disp_bottom.xz) * INV_TILE_SIZE;
        
        float J = (1.0 + dDx.x) * (1.0 + dDy.y) - dDx.y * dDy.x;
        
        
        // NOTE: normals are in tangent space for now
        imageStore(gradients, loc, vec4(gradient, 8, J));

}