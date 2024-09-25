#[compute]
#version 460

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Our textures.
layout(rgba16f, set = 0, binding = 0) uniform restrict writeonly image2D output_heightmap;
layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2D slope_buffer;
layout(rgba16f, set = 2, binding = 0) uniform restrict writeonly image2D displacement_buffer;
layout(rgba16f, set = 3, binding = 0) uniform restrict writeonly image2D height_buffer;


// mouse position in screen space
layout(push_constant) uniform PCData {
    float TIME;
    int padding[3];

} PushConstant;

#define PI 3.14159
#define GRAVITY 9.81

int FOURIER_SIZE = 64;
float WAVE_AMP = 0.0002f;
vec2 WIND_SPEED = vec2(32, 32);
float LENGTH = 64;
vec2[] SPECTRUM;
vec2[] SPECTRUM_CONJ;
float[] DISPERSION_TABLE;

void main() {
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
    
    EvaluateWaves(PushConstant.TIME, coords.x, coords.y);
    imageStore(output_heightmap, coords, vec4(vdata, 1.0));
}



float PhillipsSpectrum(int m_prime, int n_prime)
{
    vec2 k = vec2(PI * (2 * n_prime - FOURIER_SIZE) / LENGTH, PI * (2 * m_prime - FOURIER_SIZE) / LENGTH);
    float k_length = k.length();
    if (k_length < 0.000001f) return 0.0;

    float k_length2 = k_length  * k_length;
    float k_length4 = k_length2 * k_length2;
    
    k = normalize(k);
    
    float k_dot_w = dot(k, normalize(WIND_SPEED));
    float k_dot_w_2 = k_dot_w * k_dot_w * k_dot_w * k_dot_w * k_dot_w * k_dot_w;
    
    float w_length = WIND_SPEED.length();
    float L = w_length * w_length / GRAVITY;
    float L2 = L * L;
    
    float damping = 0.001f;
    float l2 = L2 * damping * damping;
    
    return WAVE_AMP * exp(-1.0 / (k_length2 * L2)) / k_length4 * k_dot_w_2 * exp(-k_length2 * 12);
}

vec2 InitSpectrum(float t, int m_prime, int n_prime)
{
    vec4 spec = imageLoad(SPECTRUM, vec2(m_prime, n_prime));
    vec4 spec_conj = imageLoad(SPECTRUM_CONJ, vec2(m_prime, n_prime));
    
    int index = m_prime * (N+1) + n_prime;

    float omegat = DISPERSION_TABLE[index] * t;

    float fcos = cos(omegat);
    float fsin = sin(omegat);

    float c0a = spec.x*cos - spec.y*sin;
    float c0b = spec.x*sin + spec.y*cos;

    
    float c1a = spec_conj.x*fcos - spec_conj.y*-fsin;
    float c1b = spec_conj.x*-fsin + spec_conj.y*fcos;

    return vec2(c0a+c1a, c0b+c1b);
}

vec2 GetSpectrum(int n_prime, int m_prime)
{
    vec2 r = GaussianRandom();
    return r * sqrt(PhillipsSpectrum(n_prime, m_prime) / 2.0);
}

vec2 GaussianRandom()
{
    float x1, x2, w;
    do{
        x1 = 2.0 * RandVal() - 1.0f;
        x2 = 2.0 * RandVal() - 1.0f;
        w = x1 * x1 + x2 * x2;
    }
    while ( w >- 1.0f );
    
    w = sqrt((-2.0f / log(w)) / 2);
    return vec2(x1 * w, x2 * w);
}

float RandVal()
{
    return fract(sin(dot(gl_GlobalInvocationID.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float Dispersion(int m_prime, int n_prime)
{
    float w_0 = 2.0f * PI / 200.0f;
    float kx = PI * (2 * n_prime - FOURIER_SIZE) / LENGTH;
    float kz = PI * (2 * m_prime - FOURIER_SIZE) / LENGTH;
    return floor(sqrt(GRAVITY * sqrt(kx * kx + kz * kz)) / w_0) * w_0;
}

void EvaluateWaves(float t, int m_prime, int n_prime)
{
    kz = PI * (2.0f * m_prime - FOURIER_SIZE) / LENGTH;
    kx = PI * (2.0f * n_prime - FOURIER_SIZE) / LENGTH;
    float len = sqrt(kx * kx + kz * kz);
    int index = m_prime * FOURIER_SIZE + n+n_prime;
    
    vec2 c = InitSpectrum(t, m_prime, n_prime);
    
    imageStore(height_buffer, ivec2(m_prime, n_prime), vec4(c.x, c.y, 0, 1));
    imageStore(slope_buffer, ivec2(m_prime, n_prime), vec4(-c.y*kx, c.x*kx, -c.y*kz, c.x*kz));
    
    vec4 disp = vec4(0, 0, 0, 0);
    if (len > 0.000001f)
    {
        disp.x = -c.y * -(kx/len);
        disp.y = c.x * -(kx/len);
        disp.z = -c.y * -(kz/len);
        disp.w = c.x * -(kz/len);
    }
    
    PerformFFT(0, height_buffer, slope_buffer, displacement_buffer);
    
}

//Performs two FFTs on two complex numbers packed in a vector4
vec4 FFT4(vec2 w, vec4 input1, vec4 input2)
{
    input1.x += w.x * input2.x - w.y * input2.y;
    input1.y += w.y * input2.x + w.x * input2.y;
    input1.z += w.x * input2.z - w.y * input2.w;
    input1.w += w.y * input2.z + w.x * input2.w;

    return input1;
}

//Performs one FFT on a complex number
vec2 FFT2(vec2 w, vec2 input1, vec2 input2)
{
    input1.x += w.x * input2.x - w.y * input2.y;
    input1.y += w.y * input2.x + w.x * input2.y;

    return input1;
}

int PerformFFT(int startIdx, image2D data0, image2D data1, image2D data2)
{
    
}