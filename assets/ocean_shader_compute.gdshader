shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform sampler2D simulation_data;

uniform float height_scale = 1.0;

void fragment()
{
	ALBEDO = texture(simulation_data, UV).rgb;
}
