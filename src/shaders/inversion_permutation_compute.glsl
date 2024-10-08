﻿#[compute]
#version 460 core

const float PI = 3.141592653;

layout(local_size_x = 16, local_size_y = 16) in;

layout(binding = 0, rgba32f) writeonly uniform image2D displacement;
layout(binding = 1, rgba32f) readonly uniform image2D height;
layout(binding = 2, rgba32f) readonly uniform image2D choppy;

layout(set = 1, binding = 0) uniform UniformBuffer{
    int pingpong;
    int N;
} u;

void main()
{
        const float lambda = 1.3f;
        ivec2 loc = ivec2(gl_GlobalInvocationID.xy);

        float sign_correction = ((((loc.x + loc.y) & 1) == 1) ? -1.0 : 1.0);
        float h = sign_correction * imageLoad(height, loc).x /float(u.N*u.N);
        vec2 D = sign_correction * imageLoad(choppy, loc).xy /float(u.N*u.N);
        
        imageStore(displacement, loc, vec4(D.x * lambda, h, D.y * lambda, 1.0));
}