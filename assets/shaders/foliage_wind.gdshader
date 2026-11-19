shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color = vec4(0.40, 0.42, 0.24, 1.0);
uniform vec4 tip_color : source_color = vec4(0.62, 0.58, 0.28, 1.0);
uniform float bend = 0.07;
varying float tip;

void vertex() {
	tip = UV.y;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 0.85 + world.x * 0.55 + world.z * 0.38) * bend * tip * tip;
	VERTEX.x += sway;
	VERTEX.z += cos(TIME * 0.62 + world.z * 0.47) * bend * 0.65 * tip * tip;
}

void fragment() {
	vec3 col = mix(base_color.rgb, tip_color.rgb, smoothstep(0.55, 1.0, tip));
	ALBEDO = col * mix(0.78, 1.0, tip);
	ROUGHNESS = 0.9;
	SPECULAR = 0.04;
}
