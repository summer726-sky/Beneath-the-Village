shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(0.32, 0.26, 0.16, 1.0);
uniform bool use_tex = false;
uniform vec3 slit_center = vec3(15.93, 1.445, 0.0);
uniform vec3 slit_half = vec3(0.85, 0.11, 0.58);
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 d = abs(world_pos - slit_center);
	if (d.x < slit_half.x && d.y < slit_half.y && d.z < slit_half.z) {
		discard;
	}
	vec3 col = albedo_color.rgb;
	if (use_tex) {
		col *= texture(albedo_tex, UV).rgb;
	}
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.03;
}
