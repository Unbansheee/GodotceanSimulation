#[compute]
#version 460 core

const float PI = 3.1415926535897932384626433832795;

layout(local_size_x = 1, local_size_y = 16) in;

layout(rgba32f, set = 0, binding = 0) uniform writeonly image2D butterfly_texture;

layout (std430, set = 1, binding = 0) restrict buffer indices {
    int j[];
} bit_reversed;

layout(set = 2, binding = 0) uniform UniformsBuffer {
    int N;
} u;

struct complex {
    float real;
    float im;
};

void main()
{
    vec2 x = vec2(gl_GlobalInvocationID.xy);
    float k = mod(x.y * (float(u.N)/ pow(2, x.x+1)), u.N);
    complex twiddle = complex(cos(2.0*PI*k/float(u.N)), sin(2.0*PI*k/float(u.N)));
    
    int butterflySpan = int(pow(2, x.x));
    int butterflyWing;
    if (mod(x.y, pow(2, x.x+1)) < pow(2, x.x))
    {
        butterflyWing = 1;
    }
    else
    {
        butterflyWing = 0;
    }
    
    if (x.x == 0)
    {
        if (butterflyWing == 1)
        {
            imageStore(butterfly_texture, ivec2(x), vec4(twiddle.real, twiddle.im, bit_reversed.j[int(x.y)], bit_reversed.j[int(x.y + 1)]));
        }
        else
        {
            imageStore(butterfly_texture, ivec2(x), vec4(twiddle.real, twiddle.im, bit_reversed.j[int(x.y - 1)], bit_reversed.j[int(x.y)]));
        }
    }
    else
    {
        if (butterflyWing == 1)
        {
            imageStore(butterfly_texture, ivec2(x), vec4(twiddle.real, twiddle.im, x.y, x.y + butterflySpan));
        }
        else
        {
            imageStore(butterfly_texture, ivec2(x), vec4(twiddle.real, twiddle.im, x.y - butterflySpan, x.y));
        }
    }
}