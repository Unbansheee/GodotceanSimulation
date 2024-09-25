#[compute]
#version 460 core

layout(local_size_x = 16, local_size_y = 16) in;

layout(binding = 0, rgba32f) uniform readonly image2D butterflyTexture;
layout(binding = 1, rgba32f) uniform image2D pingpong0;
layout(binding = 2, rgba32f) uniform image2D pingpong1;

layout(set = 1, binding = 0) uniform UniformBuffer {
    int stage;
    int pingpong;
    int direction;
} u;


struct complex {
    float real;
    float im;
};

complex mul(complex c0, complex c1) {
    complex c;
    c.real = c0.real * c1.real - c0.im * c1.im;
    c.im = c0.real * c1.im + c0.im * c1.real;
    return c;
}

complex add(complex c0, complex c1) {
    complex c;
    c.real = c0.real + c1.real;
    c.im = c0.im + c1.im;
    return c;
}

void verticalButterflies()
{
    if (u.pingpong == 0)
    {
        complex H;
        ivec2 x = ivec2(gl_GlobalInvocationID.xy);

        vec4 data = imageLoad(butterflyTexture, ivec2(u.stage, x.y)).rgba;
        vec2 p_ = imageLoad(pingpong0, ivec2(x.x, data.z)).rg;
        vec2 q_ = imageLoad(pingpong0, ivec2(x.x, data.w)).rg;

        complex p = complex(p_.x, p_.y);
        complex q = complex(q_.x, q_.y);
        complex w = complex(data.x, data.y);

        H = add(p, mul(w, q));

        imageStore(pingpong1, x, vec4(H.real, H.im, 0.0, 1.0));
    }
    else if (u.pingpong == 1)
    {
        complex H;
        ivec2 x = ivec2(gl_GlobalInvocationID.xy);

        vec4 data = imageLoad(butterflyTexture, ivec2(u.stage, x.y)).rgba;
        vec2 p_ = imageLoad(pingpong1, ivec2(x.x, data.z)).rg;
        vec2 q_ = imageLoad(pingpong1, ivec2(x.x, data.w)).rg;

        complex p = complex(p_.x, p_.y);
        complex q = complex(q_.x, q_.y);
        complex w = complex(data.x, data.y);

        H = add(p, mul(w, q));

        imageStore(pingpong0, x, vec4(H.real, H.im, 0.0, 1.0));
    }
    
}

vec2 ComplexMult(vec2 a, vec2 b)
{
    return vec2(a.r * b.r - a.g * b.g, a.r * b.g + a.g * b.r);
}

void ifftVertical()
{
    ivec2 x = ivec2(gl_GlobalInvocationID.xy);
    vec4 data = imageLoad(butterflyTexture, ivec2(u.stage, x.y)).rgba;
    uvec2 inputsIndices = uvec2(data.zw);

    if (u.pingpong == 1)
    {
        vec2 newVal = imageLoad(pingpong1, ivec2(x.x, inputsIndices.x)).rg + ComplexMult(vec2(data.r, -data.g), imageLoad(pingpong1, ivec2(x.x, inputsIndices.y)).rg);
        imageStore(pingpong0, x, vec4(newVal, 0.0, 1.0));
    }
    else if (u.pingpong == 0)
    {
        vec2 newVal = imageLoad(pingpong0, ivec2(x.x, inputsIndices.x)).rg + ComplexMult(vec2(data.r, -data.g), imageLoad(pingpong0, ivec2(x.x, inputsIndices.y)).rg);
        imageStore(pingpong1, x, vec4(newVal, 0.0, 1.0));
    }
}

void fftVertical()
{
    ivec2 x = ivec2(gl_GlobalInvocationID.xy);
    vec4 data = imageLoad(butterflyTexture, ivec2(u.stage, x.y)).rgba;
    uvec2 inputsIndices = uvec2(data.zw);

    if (u.pingpong == 1)
    {
        vec2 newVal = imageLoad(pingpong1, ivec2(x.x, inputsIndices.x)).rg + ComplexMult(vec2(data.r, data.g), imageLoad(pingpong1, ivec2(x.x, inputsIndices.y)).rg);
        imageStore(pingpong0, x, vec4(newVal, 0.0, 1.0));
    }
    else if (u.pingpong == 0)
    {
        vec2 newVal = imageLoad(pingpong0, ivec2(x.x, inputsIndices.x)).rg + ComplexMult(vec2(data.r, data.g), imageLoad(pingpong0, ivec2(x.x, inputsIndices.y)).rg);
        imageStore(pingpong1, x, vec4(newVal, 0.0, 1.0));
    }
}

void main()
{
    verticalButterflies();
}