shader_type spatial;
render_mode cull_disabled;

varying vec3 col;
varying float height;

void vertex() {
	col = COLOR.rgb;
	height = clamp(VERTEX.y / 11.2, 0.0, 1.0);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 0.5 + world.x * 0.15 + world.z * 0.12) * 0.18 * height * height;
	VERTEX.x += sway;
	VERTEX.z += cos(TIME * 0.38 + world.z * 0.1) * 0.1 * height * height;
}

void fragment() {
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.03;
}
