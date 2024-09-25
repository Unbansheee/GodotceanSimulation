#[compute]
#version 460 core

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) writeonly uniform image2D tilde_h0k;
layout(set = 0, binding = 1, rgba32f) writeonly uniform image2D tilde_h0minusk;

layout(set = 1, binding = 0) uniform sampler2D noise_r0;
layout(set = 1, binding = 1) uniform sampler2D noise_i0;
layout(set = 1, binding = 2) uniform sampler2D noise_r1;
layout(set = 1, binding = 3) uniform sampler2D noise_i1;

layout (set = 2, binding = 0) uniform UniformsBuffer {
    int N;
    int L;
    float A;
    float windDirectionX;
    float windDirectionY;
} u;

const float GRAVITY = 9.81;
const float PI = 3.1415926535897932384626433832795;
const float l = 1.5;

float philips(in vec2 wave_vector){
    vec2 wind = vec2(u.windDirectionX, u.windDirectionY);
    float V = length(wind);
    float Lp = V*V/GRAVITY;
    float k = length(wave_vector);
    k = max(k, 0.1);

    return clamp(sqrt(
    u.A
    *pow(dot(normalize(wave_vector), normalize(wind)), 2.0)
    *exp(-1.f/(pow(k*Lp,2.0)))
    *exp(-1.f*pow(k*l,2.0))
    )/(k*k), 0, 4000);
}

vec2 conj(const vec2 a){
    return vec2(a.x, -a.y);
}

vec4 GaussRND()
{
    vec2 texCoord = vec2(gl_GlobalInvocationID.xy) / float(u.N);

    float noise00 = clamp(texture(noise_r0, texCoord).r, 0.001, 1.0);
    float noise01 = clamp(texture(noise_i0, texCoord).r, 0.001, 1.0);
    float noise02 = clamp(texture(noise_r1, texCoord).r, 0.001, 1.0);
    float noise03 = clamp(texture(noise_i1, texCoord).r, 0.001, 1.0);

    float u0 = 2.0*PI*noise00;
    float v0 = sqrt(-2.0 * log(noise01));
    float u1 = 2.0*PI*noise02;
    float v1 = sqrt(-2.0 * log(noise03));

    vec4 rnd = vec4(v0 * cos(u0), v0 * sin(u0), v1 * cos(u1), v1 * sin(u1));

    return rnd;
}

float hash(uint x) {
// integer hash copied from Hugo Elias
x = (x << 13) ^ x;

float t = float((x * (x * x * 15731u + 789221u) + 1376312589u) & 0x7fffffffu);

return 1.0f - (t / 1073741824.0f);
}

uvec2 UniformToGaussian(float u1, float u2) {
float R = sqrt(-2.0 * log(u1));
float theta = 2.0 * PI * u2;
return uvec2(R * cos(theta), R * sin(theta));
}
        

void main(){
    vec2 x = vec2(gl_GlobalInvocationID.xy);
    vec2 k = vec2(2.0 * PI * x.x/u.L, 2.0 * PI * x.y/u.L);

    vec2 wind = vec2(u.windDirectionX, u.windDirectionY);
    
    float intensity = length(wind);
    vec2 direction = normalize(wind);
    
    float L_ = (intensity * intensity)/GRAVITY;
    float mag = length(k);
    if (mag < 0.0001) mag = 0.0001;
    float magSq = mag * mag;

    //sqrt(Ph(k))/sqrt(2)
    float h0k = clamp(sqrt((u.A/(magSq*magSq)) * pow(dot(normalize(k), normalize(direction)), 2) *
    exp(-(1.0/(magSq * L_ * L_))) * exp(-magSq*pow(l,2.0)))/ sqrt(2.0), -4000.0, 4000.0);

    //sqrt(Ph(-k))/sqrt(2)
    float h0minusk = clamp(sqrt((u.A/(magSq*magSq)) * pow(dot(normalize(-k), normalize(direction)), 2) *
    exp(-(1.0/(magSq * L_ * L_))) * exp(-magSq*pow(l,2.0)))/ sqrt(2.0), -4000.0, 4000.0);
        
        
    vec4 gauss_random = GaussRND();

    imageStore(tilde_h0k, ivec2(gl_GlobalInvocationID.xy), vec4(gauss_random.xy * h0k, 0, 1));
    imageStore(tilde_h0minusk, ivec2(gl_GlobalInvocationID.xy), vec4(gauss_random.zw * h0minusk, 0, 1));
}
