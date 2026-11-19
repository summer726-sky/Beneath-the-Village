shader_type sky;

void sky() {
	float h = EYEDIR.y;
	vec3 zenith = vec3(0.30, 0.50, 0.78);
	vec3 midsky = vec3(0.46, 0.64, 0.84);
	vec3 horizon = vec3(0.74, 0.80, 0.84);
	float up = clamp(h, 0.0, 1.0);
	vec3 col = mix(horizon, midsky, smoothstep(0.0, 0.22, up));
	col = mix(col, zenith, smoothstep(0.12, 0.72, up));
	vec2 cloud_uv = EYEDIR.xz / max(h, 0.05);
	cloud_uv += vec2(TIME * 0.012, TIME * 0.004);
	float n = sin(cloud_uv.x * 1.7) * sin(cloud_uv.y * 1.4);
	n += sin(cloud_uv.x * 3.3 + cloud_uv.y * 2.1) * 0.55;
	n += sin(cloud_uv.x * 6.4 - cloud_uv.y * 4.2 + 1.7) * 0.28;
	float cloud = smoothstep(0.35, 0.85, n * 0.5 + 0.5);
	cloud *= smoothstep(0.02, 0.18, h);
	vec3 cloud_col = vec3(0.95, 0.96, 0.97);
	float haze = smoothstep(0.28, 0.0, h);
	col = mix(col, vec3(0.78, 0.82, 0.84), haze * 0.55);
	col = mix(col, cloud_col, cloud * 0.82);
	if (h < 0.0) {
		col = mix(vec3(0.50, 0.44, 0.34), horizon, smoothstep(-0.2, 0.0, h));
	}
	float sun = pow(max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0), 280.0);
	col += vec3(1.0, 0.94, 0.82) * sun * 0.35;
	COLOR = col;
}
