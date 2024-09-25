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
    // return clamp(sqrt(
    //         u_amplitude
    //         *pow(dot(normalize(wave_vector), normalize(u_wind)), 2.0)
    //         *exp(-1.f/(pow(k*Lp,2.0)))
    //         // *exp(-1.f*pow(k*l,2.0))
    //     )/(k*k), -4000, 4000);
    return clamp(sqrt(
    u.A
    *pow(dot(normalize(wave_vector), normalize(wind)), 2.0)
    *exp(-1.f/(pow(k*Lp,2.0)))
    *exp(-1.f*pow(k*l,2.0))
    )/(k*k), 0, 4000);
}

// COMPLEX OPERATIONS
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



/*
void main() {
    ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);
    float n = (pixel_coord.x < 0.5f * u.N) ? pixel_coord.x : pixel_coord.x - u.N;
    float m = (pixel_coord.y < 0.5f * u.N) ? pixel_coord.y : pixel_coord.y - u.N;

    ivec2 center_offset = ivec2(u.N >> 1);
    ivec2 wrapped_coord = (pixel_coord + center_offset) % u.N - center_offset;
    vec2 wave_vector = (2.f * PI * wrapped_coord) / 500.0;

    vec4 rand = GaussRND();
    vec2 E_p = rand.xy;
    vec2 E_p2 = rand.zw;
    
    float vp = philips(wave_vector)/sqrt(2.0);
    float vn = philips(-wave_vector)/sqrt(2.0);

    vec2 h = E_p*vp;
    vec2 h_est = conj(E_p2*vn);

    imageStore(tilde_h0k, pixel_coord, vec4(h, 0.0, 1.0));
    imageStore(tilde_h0minusk, pixel_coord, vec4(h_est, 0.0, 1.0));
}
*/

/*
void main() {
    vec2 windDirection = vec2(u.windDirectionX, u.windDirectionY);
    float windspeed = length(windDirection);
    float l2 = 1.5;
    ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);

    ivec2 center_offset = ivec2(u.N >> 1);
    ivec2 wrapped_coord = (pixel_coord + center_offset) % u.N - center_offset;
    vec2 wave_vector = (2.f * PI * wrapped_coord) / u.L;
    
    vec2 k = wave_vector ;
    
    
    float L_ = (windspeed * windspeed)/GRAVITY;
    float mag = length(k);
    if (mag < 0.0001) mag = 0.0001;
    float magSq = mag*mag;

    //sqrt(Ph(k))/sqrt(2)
    float h0k = clamp(sqrt((u.A/(magSq*magSq)) * pow(dot(normalize(k), normalize(windDirection)), 2) *
    exp(-(1.0/(magSq * L_ * L_))) * exp(-magSq*pow(l2,2.0)))/ sqrt(2.0), -4000.0, 4000.0);

    
    
    //sqrt(Ph(-k))/sqrt(2)
    float h0minusk = clamp(sqrt((u.A/(magSq*magSq)) * pow(dot(normalize(-k), normalize(windDirection)), 2) *
    exp(-(1.0/(magSq * L_ * L_))) * exp(-magSq*pow(l2,2.0)))/ sqrt(2.0), -4000.0, 4000.0);
    
    vec4 gauss_random = GaussRND();
   
    imageStore(tilde_h0k, pixel_coord, vec4(gauss_random.xy*h0k, 0, 1));
    imageStore(tilde_h0minusk, pixel_coord, vec4(gauss_random.zw*h0minusk, 0, 1));
}
*/

/*
void main() {
    vec2 x = vec2(gl_GlobalInvocationID.xy) - float(u.N)/2.0;
    vec2 k = vec2(2.0 * PI * x.x/u.L, 2.0 * PI * x.y/u.L);

    vec2 windDirection = vec2(u.windDirectionX, u.windDirectionY);
    float windspeed = length(windDirection);
    
    float L_ = (windspeed * windspeed)/GRAVITY;
    float mag = length(k);
    if (mag < 0.0001) mag = 0.0001;
    float magSq = mag*mag;

    //sqrt(Ph(k))/sqrt(2)
    float h0k = clamp(sqrt((u.A/(magSq*magSq)) * 
    pow(dot(normalize(k), normalize(windDirection)), 2) *
    exp(-(1.0/(magSq * L_ * L_))) * 
    exp(-magSq*pow(u.L/500.0,2.0)))/ sqrt(2.0), -4000.0, 4000.0);

    //sqrt(Ph(-k))/sqrt(2)
    float h0minusk = clamp(sqrt((u.A/(magSq*magSq)) *
    pow(dot(normalize(-k), normalize(windDirection)), 6) *
    exp(-(1.0/(magSq * L_ * L_))) *
    exp(-magSq*pow(u.L/500.0,2.0)))/ sqrt(2.0), -4000.0, 4000.0);

    vec4 gauss_random = GaussRND();

    imageStore(tilde_h0k, ivec2(gl_GlobalInvocationID.xy), vec4(gauss_random.xy*h0k, 0, 1));
    imageStore(tilde_h0minusk, ivec2(gl_GlobalInvocationID.xy), vec4(gauss_random.zw*h0minusk, 0, 1));
}
*/



/*
//JONSWAP SPECTRUM

const float cutoffHigh = 4000;
const float cutoffLow = -4000;
const float depth = 1000.0;
struct SpectrumParameters
{
    float scale;
    float angle;
    float spreadBlend;
    float swell;
    float alpha;
    float peakOmega;
    float gamma;
    float shortWavesFade;
};

float ShortWavesFade(float kLength, SpectrumParameters spec) {
    return exp(-spec.shortWavesFade * spec.shortWavesFade * kLength * kLength);
}

float NormalisationFactor(float s) {
    float s2 = s * s;
    float s3 = s2 * s;
    float s4 = s3 * s;
    if (s < 5.0)
        return -0.000564 * s4 + 0.00776 * s3 - 0.044 * s2 + 0.192 * s + 0.163;
    else
        return -4.80e-08 * s4 + 1.07e-05 * s3 - 9.53e-04 * s2 + 5.90e-02 * s + 3.93e-01;
}

float SpreadPower(float omega, float peakOmega) {
    if (omega > peakOmega) {
        return 9.77 * pow(abs(omega / peakOmega), -2.5);
    } else {
        return 6.97 * pow(abs(omega / peakOmega), 5);
    }
}


float Cosine2s(float theta, float s) {
    return NormalisationFactor(s) * pow(abs(cos(0.5 * theta)), 2.0 * s);
}

float DirectionSpectrum(float theta, float omega, SpectrumParameters pars) {
    float s = SpreadPower(omega, pars.peakOmega)
    + 16.0 * tanh(min(omega / pars.peakOmega, 20.0)) * pars.swell * pars.swell;
    return mix(2.0 / 3.1415 * cos(theta) * cos(theta), Cosine2s(theta - pars.angle, s), pars.spreadBlend);
}


float Frequency(float k, float g, float depth) {
    return sqrt(g * k * tanh(min(k * depth, 20.0)));
}

float FrequencyDerivative(float k, float g, float depth) {
    float th = tanh(min(k * depth, 20.0));
    float ch = cosh(k * depth);
    return g * (depth * k / (ch * ch) + th) / (2.0 * Frequency(k, g, depth));
}


float TMACorrection(float omega, float g, float depth) {
    float omegaH = omega * sqrt(depth / g);
    if (omegaH <= 1.0) return 0.5 * omegaH * omegaH;
    if (omegaH < 2.0) return 1.0 - 0.5 * (2.0 - omegaH) * (2.0 - omegaH);
    return 1.0;
}

float JONSWAP(float omega, SpectrumParameters spectrum) {
    float sigma = (omega <= spectrum.peakOmega) ? 0.07f : 0.09f;

    float r = exp(-(omega - spectrum.peakOmega) * (omega - spectrum.peakOmega) / 2.0f / sigma / sigma / spectrum.peakOmega / spectrum.peakOmega);

    float oneOverOmega = 1.0f / omega;
    float peakOmegaOverOmega = spectrum.peakOmega / omega;
    return spectrum.scale * TMACorrection(omega, GRAVITY, depth) * spectrum.alpha * GRAVITY * GRAVITY
    * oneOverOmega * oneOverOmega * oneOverOmega * oneOverOmega * oneOverOmega
    * exp(-1.25f * peakOmegaOverOmega * peakOmegaOverOmega * peakOmegaOverOmega * peakOmegaOverOmega)
    * pow(abs(spectrum.gamma), r);
}

float Dispersion(float kMag, float grav, float depth) {
    return sqrt(grav * kMag * tanh(min(kMag * depth, 20)));
}

float DispersionDerivative(float kMag, float grav, float depth) {
    float th = tanh(min(kMag * depth, 20));
    float ch = cosh(kMag * depth);
    return grav * (depth * kMag / ch / ch + th) / Dispersion(kMag, grav, depth) / 2.0f;
}

*/





/*
void main()
{
    float deltaK = 2.0 * PI / 1000.0;
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
    int nx = int(gl_GlobalInvocationID.x - u.N / 2);
    int nz = int(gl_GlobalInvocationID.x - u.N / 2);
    vec2 k = vec2(nx, nz) * deltaK;
    float kLength = length(k);
    
    SpectrumParameters spec;
    spec.alpha = 1;
    spec.peakOmega = 1; 
    spec.angle = 1;
    spec.gamma = 1;
    spec.scale = 1;
    spec.shortWavesFade = 00.5;
    spec.spreadBlend = 0.5;
    spec.swell = 1;

    if (kLength <= cutoffHigh && kLength >= cutoffLow)
    {
        float kAngle = atan(k.y, k.x);
        float omega = Frequency(kLength, GRAVITY, depth);
        //WavesData[id.xy] = vec4(k.x, 1 / kLength, k.y, omega);
        float dOmegadk = FrequencyDerivative(kLength, GRAVITY, depth);

        float spectrum = JONSWAP(omega, spec)
        * DirectionSpectrum(kAngle, omega, spec) * ShortWavesFade(kLength, spec);
        /*
        if (Spectrums[1].scale > 0)
            spectrum += JONSWAP(omega, GRAVITY, depth, Spectrums[1])
            * DirectionSpectrum(kAngle, omega, Spectrums[1]) * ShortWavesFade(kLength, Spectrums[1]);
        

        vec4 noise = GaussRND();
        vec4 val = noise * sqrt(2 * spectrum * abs(dOmegadk) / kLength * deltaK * deltaK);
        imageStore(tilde_h0k, coords, vec4(val.xy, 0, 1));
        
    }
    else
    {
        imageStore(tilde_h0k, coords, vec4(0, 0, 0, 1));
        //WavesData[id.xy] = float4(k.x, 1, k.y, 0);
    }

}
*/


/*
void main()
{
    SpectrumParameters spec;
    spec.alpha = 1;
    spec.peakOmega = 1;
    spec.angle = 1;
    spec.gamma = 1;
    spec.scale = 3;
    spec.shortWavesFade = 00.1;
    spec.spreadBlend = 0.1;
    spec.swell = 1;
    
    ivec2 id = ivec2(gl_GlobalInvocationID.xy);
    uint seed = uint(id.x + u.N * id + u.N);
    float lengthScale = 500.0;
    
    float halfN = u.N / 2.0;
    float deltaK = 2.0f / lengthScale;
    vec2 k = (id.xy - halfN) * deltaK;
    float kLength = length(k);
    
    vec4 uniformRandSamples = GaussRND();
    vec2 gauss1 = uniformRandSamples.xy;
    vec2 gauss2 = uniformRandSamples.zw;
    
    if (cutoffLow <= kLength && kLength <= cutoffHigh)
    {
        {
            float kAngle = atan(k.y, k.x);
            float omega = Dispersion(kLength, GRAVITY, depth);

            float dOmegadk = DispersionDerivative(kLength, GRAVITY, depth);

            float spectrum = JONSWAP(omega, spec) * DirectionSpectrum(kAngle, omega, spec) * ShortWavesFade(kLength, spec);

            vec2 h0 = vec2(gauss2.x, gauss1.y) * sqrt(2 * spectrum * abs(dOmegadk) / kLength * deltaK * deltaK);
            vec4 val = vec4(h0, 0.0f, 1.0f);
            imageStore(tilde_h0k, id, val);
        }
        {
            float kAngle = atan(-k.y, -k.x);
            float omega = Dispersion(kLength, GRAVITY, depth);

            float dOmegadk = DispersionDerivative(kLength, GRAVITY, depth);

            float spectrum = JONSWAP(omega, spec) * DirectionSpectrum(kAngle, omega, spec) * ShortWavesFade(kLength, spec);

            vec2 h0 = vec2(gauss1.x, gauss2.y) * sqrt(2 * spectrum * abs(dOmegadk) / kLength * deltaK * deltaK);
            vec4 val = vec4(h0, 0.0f, 1.0f);
            imageStore(tilde_h0minusk, id, val);
        }
        
    }
}
*/