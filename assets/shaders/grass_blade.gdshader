shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color = vec4(0.40, 0.38, 0.26, 1.0);
varying float tip;

void vertex() {
	tip = clamp((VERTEX.y + 0.16) / 0.32, 0.0, 1.0);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wave = sin(TIME * 0.7 + world.x * 0.42 + world.z * 0.31) * 0.055 * tip;
	VERTEX.x += wave;
	VERTEX.z += cos(TIME * 0.55 + world.z * 0.37) * 0.04 * tip;
}

void fragment() {
	ALBEDO = mix(base_color.rgb * 0.82, base_color.rgb * 0.95, tip);
	ROUGHNESS = 0.96;
	SPECULAR = 0.04;
}
