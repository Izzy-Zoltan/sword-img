shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.05, 0.2, 0.05, 0.8);
uniform float glow_intensity : hint_range(0.0, 8.0) = 2.0;

void fragment() {
	ALBEDO = outline_color.rgb * glow_intensity;
}
