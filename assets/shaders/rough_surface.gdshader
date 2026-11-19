shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.45, 0.38, 0.30, 1.0);
uniform float pit = 0.015;
uniform float grain = 2.4;
uniform float wind = 0.0;
uniform float soil = 0.0;
uniform float damp = 0.0;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float use_tex = 0.0;
varying float dent;
varying float wall_y;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float bowls = 0.0;
	vec2 xz = world.xz;
	bowls += smoothstep(0.62, 0.1, length(xz - vec2(-8.3, 2.55))) * 0.65;
	bowls += smoothstep(0.95, 0.18, length(xz - vec2(-1.45, -4.75))) * 1.0;
	bowls += smoothstep(0.42, 0.08, length(xz - vec2(-9.65, -1.3))) * 0.5;
	dent = bowls;
	wall_y = world.y;
	if (soil > 0.5 && NORMAL.y > 0.55) {
		VERTEX.y -= bowls * 0.045;
	} else {
		float h = sin(VERTEX.x * grain) * cos(VERTEX.z * grain * 0.73) * sin(VERTEX.y * grain * 1.17);
		VERTEX += NORMAL * h * pit;
	}
	float crown = smoothstep(0.15, 1.0, VERTEX.y);
	VERTEX.x += sin(TIME * 0.85 + world.z * 0.35) * wind * crown;
	VERTEX.z += cos(TIME * 0.7 + world.x * 0.28) * wind * crown * 0.65;
}

void fragment() {
	vec3 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float grit = sin(p.x * 7.5) * sin(p.z * 6.2) * 0.045;
	grit += sin(p.x * 23.0 + p.z * 17.0) * 0.03;
	float pitdark = dent * 0.1;
	vec3 col = base_color.rgb;
	if (use_tex > 0.5) {
		vec2 uv = p.xz * 0.35;
		col = mix(col, texture(albedo_tex, uv).rgb, 0.55);
	}
	if (soil > 0.5) {
		float patch = sin(p.x * 0.33 + 1.7) * cos(p.z * 0.27);
		col *= 0.86 + patch * 0.12 + sin(p.x * 1.7 + p.z * 1.1) * 0.04;
		// 近地更湿暗，顶板更闷；院子地表 damp 较低仍同族
		float low = smoothstep(-2.0, -3.9, wall_y);
		float high = smoothstep(-3.2, -2.0, wall_y);
		float yard = smoothstep(0.4, -0.2, wall_y);
		col *= mix(1.0, 0.78, damp * low);
		col *= mix(1.0, 0.88, damp * high * 0.65);
		col *= mix(1.0, 0.92, damp * yard * 0.4);
	}
	ALBEDO = col * (0.94 + grit - pitdark);
	ROUGHNESS = clamp(0.9 + grit + damp * 0.04, 0.82, 1.0);
	SPECULAR = mix(0.03, 0.06, damp * 0.35);
}
