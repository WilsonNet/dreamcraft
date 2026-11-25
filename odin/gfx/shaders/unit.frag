#version 450
layout(location=0) in vec3 v_world;
layout(location=1) in vec3 v_normal;
layout(location=2) in vec4 v_albedo;
layout(location=3) in vec2 v_look;
layout(std140, set=3, binding=0) uniform U { mat4 mvp; mat4 matModel; vec4 colDiffuse; vec4 fb; vec4 u_camera; vec4 u_key_dir; vec4 u_time; vec4 u_tint; vec4 u_fog_vis; };
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
void main() {
	vec3 N = normalize(v_normal);
	vec3 V = normalize(u_camera.xyz - v_world);
	if (dot(N, V) < 0.0) {
		N = -N;
	}

	float ao = clamp(v_albedo.a, 0.0, 1.0);
	float metal = clamp(v_look.x, 0.0, 1.0);
	float glow = clamp(v_look.y, 0.0, 1.0);
	vec3 albedo = v_albedo.rgb * u_tint.xyz;

	vec3 L = normalize(u_key_dir.xyz);
	vec3 F = normalize(vec3(-0.62, 0.34, 0.70));
	float ndl = dot(N, L);
	float ndv = clamp(dot(N, V), 0.0, 1.0);

	float key = smoothstep(-0.22, 0.86, ndl);
	float fill = (dot(N, F) * 0.5 + 0.5) * 0.24;
	float sky = 0.12 + 0.10 * clamp(N.y, 0.0, 1.0);
	float wash = (value_noise(v_world.xz * 7.5 + v_world.y * 4.5) - 0.5) * 0.085;
	float lv = clamp(key * 0.78 + fill + sky * 0.65 + wash - (1.0 - ao) * 0.18, 0.0, 1.0);

	float t1 = smoothstep(0.20, 0.28, lv);
	float t2 = smoothstep(0.44, 0.52, lv);
	float t3 = smoothstep(0.74, 0.82, lv);

	vec3 c0 = albedo * vec3(0.44, 0.46, 0.68);
	vec3 c1 = albedo * vec3(0.68, 0.70, 0.86);
	vec3 c2 = albedo * vec3(1.00, 0.99, 0.96);
	vec3 c3 = mix(albedo * vec3(1.12, 1.07, 0.93), vec3(1.00, 0.97, 0.88), 0.14);

	vec3 col = mix(c0, c1, t1);
	col = mix(col, c2, t2);
	col = mix(col, c3, t3);

	float tp = (lv - 0.48) / 0.055;
	float term_pool = exp(-(tp * tp));
	col *= 1.0 - term_pool * 0.06;
	col *= mix(0.76, 1.03, ao);

	vec3 H = normalize(L + V);
	float spec_pow = mix(28.0, 120.0, metal);
	float spec_raw = pow(max(dot(N, H), 0.0), spec_pow);
	float spec = mix(spec_raw * 0.25, smoothstep(0.18, 0.55, spec_raw), step(0.25, metal));
	col += vec3(1.00, 0.96, 0.86) * spec * (0.04 + 0.34 * metal) * (0.35 + 0.65 * t2) * ao;

	float grazing = 1.0 - ndv;
	float silhouette = smoothstep(0.55, 0.96, grazing);
	vec3 rim_warm = vec3(1.00, 0.84, 0.54);
	vec3 rim_cool = vec3(0.48, 0.66, 0.94);
	vec3 rim = mix(rim_cool, rim_warm, smoothstep(-0.10, 0.82, ndl));
	col = mix(col, col * vec3(0.44, 0.42, 0.56), silhouette * 0.40);
	col += rim * smoothstep(0.50, 0.92, grazing) * (0.10 + 0.14 * ao);

	float vis = clamp(u_fog_vis.x, 0.0, 1.0);
	float pulse = 0.86 + 0.14 * sin(u_time.x * 2.4 + v_world.y * 5.0);
	col += albedo * glow * (1.25 * pulse + 0.55) * vis;

	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(grey), col, 1.10);

	vec3 fog_mem = mix(vec3(grey), col, 0.52) * vec3(0.32, 0.41, 0.53) + vec3(0.014, 0.022, 0.034);
	col = mix(fog_mem, col, smoothstep(0.36, 1.0, vis));

	o_color = vec4(clamp(col, 0.0, 1.0), 1.0);
}
