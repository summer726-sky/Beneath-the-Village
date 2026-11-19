shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float bend = 0.08;
uniform float height_ref = 1.0;
uniform float hide_pale = 0.0;

void vertex() {
	float h = clamp(VERTEX.y / max(height_ref, 0.001), 0.0, 1.0);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float gust = sin(TIME * 1.15 + world.x * 0.35 + world.z * 0.28);
	VERTEX.x += gust * bend * h * h;
	VERTEX.z += cos(TIME * 0.85 + world.z * 0.22) * bend * 0.65 * h * h;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	float mx = max(tex.r, max(tex.g, tex.b));
	float mn = min(tex.r, min(tex.g, tex.b));
	if (hide_pale > 0.5 && mx > 0.42 && mx - mn < 0.16) {
		discard;
	}
	ALBEDO = tex.rgb;
	ROUGHNESS = 0.9;
	SPECULAR = 0.04;
}
