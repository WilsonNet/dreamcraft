#version 450
layout(location=0) in vec2 v_uv;
layout(location=1) in vec3 v_world;
layout(set=2, binding=0) uniform sampler2D texture0;
layout(set=2, binding=1) uniform sampler2D texture1;
layout(std140, set=3, binding=0) uniform U { mat4 mvp; mat4 matModel; vec4 colDiffuse; vec4 fb; vec4 s_time; };
layout(location=0) out vec4 o_color;
float hash12(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbm(vec2 p) {
	float v = value_noise(p) * 0.55;
	v += value_noise(p * 2.07 + vec2(13.1, 29.3)) * 0.30;
	v += value_noise(p * 4.19 + vec2(41.7, 17.9)) * 0.15;
	return v;
}
void main() {
	float t = s_time.x;
	vec2 wp = v_world.xz;
	float mist_a = fbm(wp * 0.55 + vec2(t * 0.025, -t * 0.018));
	float mist_b = fbm(wp * 1.15 + vec2(-t * 0.018, t * 0.022) + 7.3);
	vec2 mist_disp = (vec2(mist_a, mist_b) - 0.5) * vec2(1.4 / 80.0, 1.4 / 50.0);
	float fog_raw = texture(texture1, clamp(v_uv + mist_disp, 0.002, 0.998)).r;
	float edge_band = 4.0 * fog_raw * (1.0 - fog_raw);
	float fog_val = clamp(fog_raw + (mist_a - 0.5) * 0.14 * edge_band, 0.0, 1.0);
	float explored_vis = smoothstep(0.08, 0.42, fog_val);
	float active_vis = smoothstep(0.58, 0.92, fog_val);
	float grain = value_noise(wp * 3.8) * 0.6 + value_noise(wp * 9.5 + 4.1) * 0.4;
	vec3 albedo = texture(texture0, v_uv).rgb;
	vec3 lit = albedo * vec3(1.03, 1.01, 0.96) * (1.0 + (grain - 0.5) * 0.045);
	float gd = (v_world.x - 37.05) / 0.26;
	float goal_band = exp(-(gd * gd));
	float shimmer_wave = 0.55 + 0.45 * sin(v_world.z * 1.6 - t * 1.9 + mist_b * 4.0);
	lit += vec3(0.24, 0.19, 0.06) * goal_band * shimmer_wave;
	float lum = dot(lit, vec3(0.299, 0.587, 0.114));
	vec3 moonlit = mix(vec3(lum), lit, 0.52) * vec3(0.32, 0.41, 0.53) + vec3(0.015, 0.024, 0.036);
	vec3 ground_col = mix(moonlit, lit, active_vis);
	vec3 void_col = vec3(0.032, 0.052, 0.052);
	float edge_x = smoothstep(0.0, 0.018, v_uv.x) * smoothstep(0.0, 0.018, 1.0 - v_uv.x);
	float edge_y = smoothstep(0.0, 0.024, v_uv.y) * smoothstep(0.0, 0.024, 1.0 - v_uv.y);
	float vis_world = explored_vis * edge_x * edge_y;
	float mist_edge = vis_world * (1.0 - vis_world) * 4.0;
	vec3 col = mix(void_col, ground_col, vis_world);
	col += vec3(0.020, 0.034, 0.040) * mist_edge * (0.65 + 0.35 * mist_a);
	o_color = vec4(clamp(col, 0.0, 1.0), 1.0);
}
