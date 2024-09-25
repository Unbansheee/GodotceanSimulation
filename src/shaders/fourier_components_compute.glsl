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

        // take advantage of DFT's linearity
        vec2 Dt_x = vec2(h_tk.y * nk.x, -h_tk.x * nk.x);
        vec2 iDt_z = vec2(h_tk.x * nk.y, h_tk.y * nk.y);
        
        // write ouptut
        imageStore(tilde_hkt_dy, loc1, vec4(h_tk, 0.0, 1.0));
        imageStore(tilde_hkt_D, loc1, vec4(Dt_x + iDt_z, 0.0, 1.0));
}
        
        
/*
// COMPLEX OPERATIONS
vec2 prod(const vec2 a, const vec2 b){
    return vec2(a.x*b.x - a.y*b.y, a.x*b.y + a.y*b.x);
}
vec2 conj(const vec2 a){
    return vec2(a.x, -a.y);
}
vec2 euler(const float x){
    return vec2(cos(x), sin(x));
}

float omega(float k)
{
    return sqrt(GRAVITY * k);
}


void main(void)
{
    ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);
    float n = (pixel_coord.x < 0.5f * u.N) ? pixel_coord.x : pixel_coord.x - u.N;
    float m = (pixel_coord.y < 0.5f * u.N) ? pixel_coord.y : pixel_coord.y - u.N;

    // vec2 wave_vector = (2.f * PI * (pixel_coord - (u_resolution>>1))) / u_ocean_size;
    // vec2 wave_vector = (2.f * PI * vec2(n, m)) / u_ocean_size;
    // vec2 wave_vector = (2.f * PI * ((pixel_coord + (u_resolution>>1))%(u_resolution))) / u_ocean_size;

    ivec2 center_offset = ivec2(u.N >> 1);
    ivec2 wrapped_coord = (pixel_coord + center_offset) % u.N - center_offset;
    vec2 wave_vector = (2.f * PI * wrapped_coord) / 500.0;


    float k = length(wave_vector);

    float phase = omega(k) * pc.t;

    vec2 h0 = imageLoad(tilde_h0k, pixel_coord).rg;
    ivec2 inv_pixel_coord = (u.N - pixel_coord);
    vec2 h0_est = imageLoad(tilde_h0minusk, inv_pixel_coord).rg;
    // vec2 h0_est = imageLoad(u_initial_spectrum, pixel_coord).ba;

    vec2 h = prod(h0, euler(phase)) + prod(h0_est, euler(-phase));
    vec2 nx = prod(vec2(0,1), h) * wave_vector.x;
    vec2 nz = prod(vec2(0,1), h) * wave_vector.y;

    k = max(k, 0.1);
    vec2 Dz = -nz/k * 1.0;
    vec2 Dx = -nx/k * 1.0;

    // vec2 Dx = (k == 0) ? vec2(0) : prod(vec2(0,-1), h) * wave_vector.x/k * u_choppiness;
    // vec2 Dz = (k == 0) ? vec2(0) : prod(vec2(0,-1), h) * wave_vector.y/k * u_choppiness;

    // imageStore(u_vertical_displacement, pixel_coord, vec4(h, 0.f, 0.f));
    // imageStore(u_dx_displacement, pixel_coord, vec4(Dx, 0.f, 0.f));
    // imageStore(u_dz_displacement, pixel_coord, vec4(Dz,  0.f, 0.f));
    imageStore(tilde_hkt_dy, pixel_coord, vec4(h, 0.f, 1.f));
    imageStore(tilde_hkt_dx, pixel_coord, vec4(Dx,nx));
    imageStore(tilde_hkt_dz, pixel_coord, vec4(Dz,nz));

}
*/

/*
vec2 EulerFormula(float x) {
    return vec2(cos(x), sin(x));
}

vec2 ComplexMult(vec2 a, vec2 b) {
    return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

const float RepeatTime = 100.0;
const float FrameTime = 1.0/60.0;

void main()
{
    ivec2 id = ivec2(gl_GlobalInvocationID);
    vec2 h0 = imageLoad(tilde_h0k, id).xy;
    vec2 h0conj = imageLoad(tilde_h0minusk, id).xy;
    
    float halfN = u.N / 2.0;
    vec2 k = (id.xy - halfN) * 2.0f * PI / 500.0;
    float kMag = length(k);
    float kMagRcp = 1/kMag; // todo
    
    if (kMag < 0.0001f)
    {
        kMagRcp = 1.0f;
    }
    
    float w_0 = 2.0f * PI / RepeatTime;
    float dispersion = floor(sqrt(GRAVITY * kMag) / w_0) * w_0 * pc.t;
    
    vec2 exponent = EulerFormula(dispersion); // todo
    
    vec2 htilde = ComplexMult(h0, exponent) + ComplexMult(h0conj, vec2(exponent.x, -exponent.y));
    vec2 ih = vec2(-htilde.y, htilde.x);
    
    vec2 displacementX = ih * k.x * kMagRcp;
    vec2 displacementY = htilde;
    vec2 displacementZ = ih * k.y * kMagRcp;

    vec2 displacementX_dx = -htilde * k.x * k.x * kMagRcp;
    vec2 displacementY_dx = ih * k.x;
    vec2 displacementZ_dx = -htilde * k.x * k.y * kMagRcp;

    vec2 displacementY_dz = ih * k.y;
    vec2 displacementZ_dz = -htilde * k.y * k.y * kMagRcp;

    vec2 htildeDisplacementX = vec2(displacementX.x - displacementZ.y, displacementX.y + displacementZ.x);
    vec2 htildeDisplacementZ = vec2(displacementY.x - displacementZ_dx.y, displacementY.y + displacementZ_dx.x);

    vec2 htildeSlopeX = vec2(displacementY_dx.x - displacementY_dz.y, displacementY_dx.y + displacementY_dz.x);
    vec2 htildeSlopeZ = vec2(displacementX_dx.x - displacementZ_dz.y, displacementX_dx.y + displacementZ_dz.x);
    
    imageStore(tilde_hkt_dy, id, vec4(displacementY, 0.0, 1.0));
}
*/





/*

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

complex conj(complex c) {
    complex c_conj = complex(c.real, -c.im);
    return c_conj;
}


void main() {
    vec2 x = vec2(gl_GlobalInvocationID.xy) - float(u.N)/2.0;
    vec2 k = vec2(2.0 * PI * x.x/u.L, 2.0 * PI * x.y/u.L);
    
    float magnitude = length(k);
    if (magnitude < 0.0001) magnitude = 0.0001;
    
    float w = sqrt(9.81 * magnitude);
    complex fourier_amp 	 	 = complex(imageLoad(tilde_h0k, ivec2(gl_GlobalInvocationID.xy)).r,
                                            imageLoad(tilde_h0k, ivec2(gl_GlobalInvocationID.xy)).g);

    complex fourier_amp_conj   = conj(complex(imageLoad(tilde_h0minusk, ivec2(gl_GlobalInvocationID.xy)).r,
                                            imageLoad(tilde_h0minusk, ivec2(gl_GlobalInvocationID.xy)).g));
    
    float cosinus = cos(w * float(pc.t / 1000.0));
    float sinus = sin(w * float(pc.t / 1000.0));
    
    //euler formula
    complex e_iwt = complex(cosinus, sinus);
    complex e_iwt_inv = complex(cosinus, -sinus);
    
    //dy
    complex hktdy = add(mul(fourier_amp, e_iwt),
        (mul(fourier_amp_conj, e_iwt_inv)));
    
    // dx
    complex dx = complex(0.0, -k.x/magnitude);
    complex hktdx = mul(dx, hktdy);
    
    //dz
    complex dy = complex(0.0, -k.y/magnitude);
    complex hktdz = mul(dy, hktdy);
    
    
    imageStore(tilde_hkt_dy, ivec2(gl_GlobalInvocationID.xy), vec4(hktdy.real, hktdy.im, 0.0, 1.0));
    imageStore(tilde_hkt_dx, ivec2(gl_GlobalInvocationID.xy), vec4(hktdx.real, hktdx.im, 0.0, 1.0));
    imageStore(tilde_hkt_dz, ivec2(gl_GlobalInvocationID.xy), vec4(hktdz.real, hktdz.im, 0.0, 1.0));
}
*/
