#[compute]
#version 460

// Invocations in the (x, y, z) dimension
layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

// Our textures.
layout(r32f, set = 0, binding = 0) uniform restrict readonly image2D current_heightmap;
layout(r32f, set = 1, binding = 0) uniform restrict readonly image2D previous_heightmap;
layout(r32f, set = 2, binding = 0) uniform restrict writeonly image2D output_heightmap;

#define PI 3.14159265358979323846
#define Gravity 9.81f
#define Depth 1000.0f
#define N 0
#define Seed 0
#define LengthScale0 1000.0f
#define LengthScale1 100.0f
#define LengthScale2 10.0f
#define LengthScale3 1.0f

image2DArray SpectrumTextures, InitialSpectrumTextures, DisplacementTextures;


struct SpectrumParams
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

float tma_correction(float omega)
{
	float omegaH = omega * sqrt(Depth / Gravity);
	if (omegaH <= 1.0f)
	{
		return 0.5f * omegaH * omegaH;
	}
	if (omegaH < 2.0f)
	{
		return 1.0f - 0.5f * (2.0f - omegaH) * (2.0f - omegaH);
	}
	return 1.0f;
}

float jonswap(float omega, SpectrumParams spectrum)
{
	float sigma = (omega <= spectrum.peakOmega) ? 0.07f : 0.09f;
	float r = exp(-pow(omega - spectrum.peakOmega, 2) / 2.0f / sigma / sigma/ spectrum.peakOmega / spectrum.peakOmega);
	float peakOmegaOverOmega = spectrum.peakOmega / omega;
	float oneOverOmega = 1.0f / omega;
	return spectrum.scale * tma_correction(omega) * spectrum.alpha * Gravity * Gravity * oneOverOmega * oneOverOmega * oneOverOmega * oneOverOmega * oneOverOmega * exp(-1.25f * peakOmegaOverOmega * peakOmegaOverOmega * peakOmegaOverOmega * peakOmegaOverOmega) * pow(abs(spectrum.gamma), r);
}

void initialize_spectrum()
{
	uint seed = gl_GlobalInvocationID.x + N * gl_GlobalInvocationID.y + N;
	seed += Seed;
	float lengthScales[4] = { LengthScale0, LengthScale1, LengthScale2, LengthScale3 };
	for (uint i = 0; i < 4; ++i)
	{
		float halfN = 0.5f * N;
		float deltaK = 2.0f * PI / (halfN * lengthScales[i]);
		vec2 K = (gl_GlobalInvocationID.xy - halfN) * deltaK;
		float kLength = length(K);
		
		seed += i + hash(seed) * 10;
		
		vec4 uniformRandSamples = vec4(hash(seed), hash(seed + 1), hash(seed + 2), hash(seed + 3));
		vec2 gauss1 = UniformToGaussian(uniformRandSamples.x, uniformRandSamples.y);
		vec2 gauss2 = UniformToGaussian(uniformRandSamples.z, uniformRandSamples.w);
		
		if (LowCutoff <= kLength && kLength <= HighCutOff)
		{
			float kAngle = atan2(K.y, K.x);
			float omega = Dispersion(kLength);
			
			float dOmegadk = DispersionDerivative(kLength);
			
			float spectrum = jonswap(omega, Spectrums[i*2]) * DirectionSpectrum(kAngle, omega, Spectrums[i*2]) * ShortWavesFade(kLength, Spectrums[i*2]);
			if (Spectrums[i * 2 + 1].scale > 0)
			{
				spectrum += jonswap(omega, Spectrums[i * 2 + 1]) * DirectionSpectrum(kAngle, omega, Spectrums[i * 2 + 1]) * ShortWavesFade(kLength, Spectrums[i * 2 + 1]);
			}
			
			vec4 val = vec4(vec2(gauss2.x, gauss1.x) * sqrt(2 * spectrum * abs(dOmegadk) / kLength * deltaK * deltaK), 0.0f, 0.0f);
			imageStore(SpectrumTextures, ivec3(gl_GlobalInvocationID.xy, i), val);
		}
		else
		{
			imageStore(SpectrumTextures, ivec3(gl_GlobalInvocationID.xy, i), vec4(0.0f, 0.0f, 0.0f, 0.0f));
		}
		
	}
}

void get_neighbour_coords(out ivec2[8] neighbour_coords, in ivec2 coords) {
	// Return the eight neighbour indices of the given index.
	// Don't worry about whether the indices are out of bounds.
	neighbour_coords = ivec2[8](
		coords + ivec2(0, 1),
		coords + ivec2(1, 0),
		coords + ivec2(0, -1),
		coords + ivec2(-1, 0),
		coords + ivec2(1, 1),
		coords + ivec2(1, -1),
		coords + ivec2(-1, -1),
		coords + ivec2(-1, 1)
	);
}



// The code we want to execute in each invocation
void main() {
	// gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
	//set heightmap pixel to random value
	ivec2 coords = ivec2(gl_GlobalInvocationID.xy);

	ivec2[8] neightbour_coords;
	get_neighbour_coords(neightbour_coords, coords);
	
}
