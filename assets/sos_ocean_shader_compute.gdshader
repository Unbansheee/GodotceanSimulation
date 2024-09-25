shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform float sim_scale = 1000;
uniform float height_scale = 1.0;
uniform float choppy_scale = 1.0;

uniform vec3 water_base_colour : source_color;
uniform vec3 water_peak_colour : source_color;

uniform float transparency : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float metallic : hint_range(0.0, 1.0, 0.01) = 0;
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float specular :hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float sss_intensity;
uniform vec4 sss_colour: source_color;

uniform float foam_bias;
uniform float foam_intensity;

uniform float ssr_resolution   : hint_range(0.1, 10.0, 0.1)		= 2.0;
uniform float ssr_max_travel   : hint_range(0.1, 200.0, 0.1) 	= 30.0;
uniform float ssr_max_diff     : hint_range(0.1, 10.0, 0.1) 	= 4.0;
uniform float ssr_mix_strength : hint_range(0.0, 1.0, 0.01) 	= 0.7;
uniform float refraction_intensity : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float max_visible_depth : hint_range(0.0, 100.0, 0.1) = 10.0;
uniform vec3 color_deep : source_color = vec3(0.0, 0.1, 0.4);

uniform vec3  border_color : source_color = vec3(1.0);
uniform float border_scale : hint_range(0.0, 5.0, 0.01) = 2.0;
uniform float border_near = 0.5;
uniform float border_far = 300.0;
uniform float border_influence = 0.5;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D simulation_data;
uniform sampler2D gradient_data;

struct Wave
{
	vec2 direction;
	float frequency;
	float amplitude;
	float phase;
	float steepness;
};

struct VertexData
{
	float height;
	vec3 normal;
};

float get_wave_coord(vec3 v, vec2 d, Wave w)
{
	return v.x * d.x + v.z * d.y;
}

float get_time(Wave w)
{
	return TIME * w.phase;
}

float sine(vec3 v, Wave w)
{
	vec2 d = w.direction;
	float xz = get_wave_coord(v, d, w);
	float t = get_time(w);
	
	return w.amplitude * sin(xz * w.frequency + t);
}

vec3 sine_normal(vec3 v, Wave w)
{
	vec2 d = w.direction;
	float xz = get_wave_coord(v, d, w);
	float t = get_time(w);
	
	vec2 n = w.frequency * w.amplitude * d * cos(xz * w.frequency + t);
	return vec3(n.x, 0.0, n.y);
}


vec3 get_view_position_from_uv(vec2 uv, float depth, mat4 inv_proj_m)
{
	vec4 position_ndc = vec4((uv * 2.0) - 1.0, depth, 1.0);
	vec4 view_position = inv_proj_m * position_ndc;
	return view_position.xyz /= view_position.w;
}

vec2 get_uv_from_view_position(vec3 position_view_space, mat4 proj_m)
{
	vec4 position_clip_space = proj_m * vec4(position_view_space.xyz, 1.0);
	vec2 position_ndc = position_clip_space.xy / position_clip_space.w;
	return position_ndc.xy * 0.5 + 0.5;
}

bool is_within_screen_boundaries(vec2 position) {
	return position.x > 0.0 && position.x < 1.0 && position.y > 0.0 && position.y < 1.0;
}

vec3 get_ssr_color(vec3 surface_view_position, vec3 normal_view_space, vec3 view_view_space, mat4 proj_m, mat4 inv_proj_m)
{
	vec3 current_position_view_space = surface_view_position;
	vec3 view_direction_view_space = view_view_space * -1.0;
	vec3 reflect_vector_view_space = normalize(reflect(view_direction_view_space.xyz, normal_view_space.xyz));

	vec2 current_screen_position = vec2(0.0);

	vec3 resulting_color = vec3(-1.0);
	for(float travel=0.0; resulting_color.x < 0.0 && travel < ssr_max_travel; travel = travel + ssr_resolution)
	{
		current_position_view_space += reflect_vector_view_space * ssr_resolution;
		current_screen_position = get_uv_from_view_position(current_position_view_space, proj_m);

		float depth_texture_probe_raw = texture(DEPTH_TEXTURE, current_screen_position).x;
		vec3 depth_texture_probe_view_position = get_view_position_from_uv(current_screen_position, depth_texture_probe_raw, inv_proj_m);

		float depth_diff = depth_texture_probe_view_position.z - current_position_view_space.z;

		resulting_color = (is_within_screen_boundaries(current_screen_position) && depth_diff >= 0.0 && depth_diff < ssr_max_diff) ? texture(SCREEN_TEXTURE, current_screen_position.xy).rgb : vec3(-1.0);
	}
	return resulting_color;
}

vec2 get_refracted_uv(vec2 raw_screen_uv, float screen_depth_raw, vec3 view, vec3 normal, mat4 proj_m, mat4 inv_proj_m)
{
		vec3 screen_view_position_original = get_view_position_from_uv(raw_screen_uv, screen_depth_raw, inv_proj_m);
		float screen_center_distance = clamp(abs(length(raw_screen_uv - vec2(0.5, 0.5))) * 2.0, 0.0, 1.0);
		float refraction_intensity_deglitched = mix(1.0 - refraction_intensity, 1.0, screen_center_distance);
		vec3 refraction_position_view_space = screen_view_position_original + normalize(refract(view, -normal, refraction_intensity_deglitched));
		vec2 refraction_uv = get_uv_from_view_position(refraction_position_view_space, proj_m);
		return refraction_uv;
}

float normalize_float(float min_v, float max_v, float value) {
	float clamped_value = clamp(value, min_v, max_v);
	return  (clamped_value - min_v) / (max_v - min_v);
}

float border(float cur_depth)
{
	return border_near * border_far / (border_far + (2.0 * cur_depth - 1.0) * (border_near - border_far));
}

void vertex() {	
	
	vec3 worldpos = (MODEL_MATRIX * vec4(VERTEX, 1)).xyz;
	vec3 vdata = vec3(texture(simulation_data, worldpos.xz / sim_scale).rgb);
	vec3 vdatalocal = (inverse(MODEL_MATRIX) * vec4(vdata, 1)).xyz;
	VERTEX.y += vdata.y * height_scale;
	VERTEX.xz += vdata.xz * choppy_scale;
	
}

void fragment() {
	
	vec3 worldpos = ((INV_VIEW_MATRIX) * vec4(VERTEX, 1.0)).xyz;

	vec3 vdata = vec3(texture(simulation_data, worldpos.xz/sim_scale).rgb);
	vdata.y *= height_scale;
	vdata.xz *= choppy_scale;
	vec3 n = vec3(0.0);
	n.xy = vdata.xz;
	
	vec4 grad = texture(gradient_data, worldpos.xz/sim_scale);
	vec3 nnew = normalize(grad.xzy);
	vec3 normynorm = normalize((transpose(INV_VIEW_MATRIX) * vec4(nnew.xyz, 1)).xyz);
	//NORMAL = normynorm;
	
	vec3 off = vec3(1.0, 1.0, 0.0);
	float hL = texture(simulation_data, (worldpos.xz - off.xz) / sim_scale).y;
	float hR = texture(simulation_data, (worldpos.xz + off.xz) / sim_scale).y;
	float hD = texture(simulation_data, (worldpos.xz - off.zy) / sim_scale).y;
	float hU = texture(simulation_data, (worldpos.xz + off.zy) / sim_scale).y;
	
	vec3 N;
	N.x = hL - hR;
	N.y = hD - hU;
	N.z = 2.0;
	N = normalize(N);
	
	//NORMAL = normalize((VIEW_MATRIX * vec4(N.xyz, 1)).xyz);

/*
	vec3 norm = cross(bitangent, tangent);
	vec3 newnorm = normalize((transpose(INV_VIEW_MATRIX) * vec4(norm.xyz, 1)).xyz);
	NORMAL = normalize(newnorm);
	*/
	


	
	float screen_depth_raw = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	vec2 refraction_uv = refraction_intensity > 0.0 ? get_refracted_uv(SCREEN_UV, screen_depth_raw, VIEW, NORMAL, PROJECTION_MATRIX, INV_PROJECTION_MATRIX) : SCREEN_UV;

	float screen_depth = texture(DEPTH_TEXTURE, refraction_uv).x;
	float surface_depth = FRAGCOORD.z;


	vec3 screen_view_position 	= get_view_position_from_uv(refraction_uv, screen_depth, INV_PROJECTION_MATRIX);
	vec3 surface_view_position 	= get_view_position_from_uv(refraction_uv, surface_depth, INV_PROJECTION_MATRIX);
	float depth_opacity = 1.0 - normalize_float(0.0, max_visible_depth, length(surface_view_position - screen_view_position));


	float border_diff = border(screen_depth_raw) - border(surface_depth);

	vec3 screen_color 				= texture(SCREEN_TEXTURE, refraction_uv).rgb;
	vec3 surface_color 				= water_base_colour;
	vec3 ssr_color 					= get_ssr_color(surface_view_position, NORMAL, VIEW, PROJECTION_MATRIX, INV_PROJECTION_MATRIX);
	vec3 color_with_transparency 	= mix(surface_color, screen_color, transparency);
	vec3 depth_color 				= mix(color_deep.rgb, color_with_transparency, depth_opacity);
	vec3 water_color 				= (ssr_color.x >= 0.0) ? mix(depth_color, ssr_color, ssr_mix_strength) : depth_color;
	vec3 bcol						= mix (water_color, border_color, border_influence);
	vec3 final_color				= mix(bcol, water_color, step(border_scale, border_diff));

	
		// tweaked from ARM/Mali's sample
	float turbulence = max(1.6 - grad.w, 0.0);
	float color_mod = 1.0 + 3.0 * smoothstep(1.2, 1.8, turbulence);
	
	//final_color = mix(final_color, water_peak_colour, clamp((vdata.y + foam_bias) * foam_intensity, 0, 1));
	//final_color = vec3(jacobian, jacobian, jacobian);
	
	ALBEDO = vec3(1,1,1);
	SPECULAR = specular;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	//SSS_STRENGTH = sss_intensity;
	//SSS_TRANSMITTANCE_COLOR = sss_colour;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
