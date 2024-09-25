#[compute]
#version 460 core

const float PI = 3.1415926535897932384626433832795;
const float GRAVITY = 9.81;

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) writeonly uniform image2D tilde_hkt_dy;
layout(set = 0, binding = 1, rgba32f) writeonly uniform image2D tilde_hkt_D;
layout(set = 0, binding = 2, rgba32f) readonly uniform image2D tilde_h0k;
layout(set = 0, binding = 3, r32f) readonly uniform image2D frequencies;

layout(set = 1, binding = 0) uniform UniformsBuffer {
    int N;
    int L;
} u;

layout(push_constant) uniform PushConstants {
    float t;
} pc;

        
void main()
{
        ivec2 loc1	= ivec2(gl_GlobalInvocationID.xy);
        ivec2 loc2	= ivec2(u.N - loc1.x, u.N - loc1.y);
    
        vec2 h_tk;
        vec2 h0_k	= imageLoad(tilde_h0k, loc1).rg;
        vec2 h0_mk	= imageLoad(tilde_h0k, loc2).rg;
        float w_k	= imageLoad(frequencies, loc1).r;

        // Euler's formula: e^{ix} = \cos x + i \sin x
        float cos_wt = cos(w_k * pc.t / 100.0);
        float sin_wt = sin(w_k * pc.t / 100.0);

        h_tk.x = cos_wt * (h0_k.x + h0_mk.x) - sin_wt * (h0_k.y + h0_mk.y);
        h_tk.y = cos_wt * (h0_k.y - h0_mk.y) + sin_wt * (h0_k.x - h0_mk.x);

        vec2 k;
        k.x = float(u.N / 2 - loc1.x);
        k.y = float(u.N / 2 - loc1.y);

        float kn2 = dot(k, k);
        vec2 nk = vec2(0.0, 0.0);

        if (kn2 > 1e-12)
            nk = normalize(k);

       
        vec2 Dt_x = vec2(h_tk.y * nk.x, -h_tk.x * nk.x);
        vec2 iDt_z = vec2(h_tk.x * nk.y, h_tk.y * nk.y);
        
        // write ouptut
        imageStore(tilde_hkt_dy, loc1, vec4(h_tk, 0.0, 1.0));
        imageStore(tilde_hkt_D, loc1, vec4(Dt_x + iDt_z, 0.0, 1.0));
}