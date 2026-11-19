shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec4 tint : source_color = vec4(0.93, 0.91, 0.86, 1.0);
uniform float drift = 0.01;

void fragment() {
	vec2 u = UV * vec2(2.2, 1.5) + vec2(TIME * drift, TIME * drift * 0.4);
	float n = sin(u.x * 6.28318) * sin(u.y * 4.7);
	n += sin(u.x * 11.0 + u.y * 3.2) * 0.4;
	float a = smoothstep(0.08, 0.82, n * 0.5 + 0.5);
	a *= smoothstep(0.0, 0.2, UV.x) * smoothstep(1.0, 0.8, UV.x);
	a *= smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.75, UV.y);
	ALBEDO = tint.rgb;
	ALPHA = a * 0.22;
}
