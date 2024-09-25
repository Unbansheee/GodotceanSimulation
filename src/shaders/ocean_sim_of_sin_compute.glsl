#[compute]
#version 460

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Our textures.
layout(rgba32f, set = 0, binding = 0) uniform restrict writeonly image2D output_heightmap;

// mouse position in screen space
layout(push_constant) uniform PCData {
    float TIME;
    int padding[3];

} PushConstant;

int wave_count = 21;

float vertex_frequency = 0.08;
float vertex_amplitude = 0.01;
float vertex_max_peak = 1.97;
float vertex_peak_offset = 0.0;
float vertex_drag = 1.82;
float vertex_seed = 1;
float vertex_frequency_mult = 1.36;
float vertex_amplitude_mult = 0.63;
float vertex_speed_ramp = 1.02;
float initial_speed = 1.0;
float vertex_seed_iter = 1.0;
float vertex_height = 1.0;

vec2 pan(vec2 coords, vec2 speed)
{
    return coords + (PushConstant.TIME * speed);
}

float sum_of_sin(float a, float b)
{
    return (sin(a) * cos(b)) + (cos(a) * sin(b));
}

float sin_wave(vec2 uv, float amplitude, float wavelength, float speed)
{
    return amplitude * sin(((uv.x + uv.y) * (2.0/wavelength)) + (PushConstant.TIME * speed)); // 2/wavelength == frequency
}

float pd(vec2 uv, float amplitude, float wavelength, float speed)
{
    return amplitude * cos(((uv.x + uv.y) * (2.0/wavelength)) + (PushConstant.TIME * speed));
}

vec3 vertexFBM(vec2 position)
{
    float f = vertex_frequency;
    float a = vertex_amplitude;
    float speed = initial_speed;
    float seed = vertex_seed;
    vec3 p = vec3(position.x, 0, position.y);
    float amplitudeSum = 0.0;
    float h = 0.0;
    vec2 n = vec2(0.0);
    vec3 normal;
    for (int i = 0; i < wave_count; ++i)
    {
        vec2 d = normalize(vec2(cos(seed), sin(seed)));
        float x = dot(d, p.xz) * f + PushConstant.TIME * speed;
        float wave = a * exp(vertex_max_peak * sin(x) - vertex_peak_offset);

        vec2 dw = f * d * (vertex_max_peak * wave * cos(x));//perhaps removevmaxpeak
        float dx = vertex_max_peak * wave * cos(x);

        h += wave;
        n += dw;

        p.xz += d * -dx * a * vertex_drag;

        amplitudeSum += a;
        f *= vertex_frequency_mult;
        a *= vertex_amplitude_mult;
        speed *= vertex_speed_ramp;
        seed += vertex_seed_iter;
    }
    vec3 fbm = vec3(h, n.x, n.y) / amplitudeSum;
    return fbm;
}

void main() {
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
    
    vec3 vdata = vertexFBM(coords);
    imageStore(output_heightmap, coords, vec4(vdata, 1.0));
}