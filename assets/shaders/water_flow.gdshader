shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform float progress = 0.0;

void fragment() {
	float along = UV.x;
	float show = 1.0 - smoothstep(progress - 0.05, progress + 0.015, along);
	float rip = sin(along * 46.0 - TIME * 2.6) * 0.5 + 0.5;
	float edge = smoothstep(0.0, 0.08, show);
	ALBEDO = mix(vec3(0.16, 0.14, 0.11), vec3(0.34, 0.30, 0.22), rip);
	ALPHA = show * edge * (0.62 + rip * 0.18);
	ROUGHNESS = 0.28;
	SPECULAR = 0.35;
}
