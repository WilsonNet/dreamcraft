#version 450
layout(location=0) in vec2 v_uv;
layout(location=1) in vec4 v_col;
layout(set=2, binding=0) uniform sampler2D texture0;
layout(std140, set=3, binding=0) uniform U { mat4 mvp; mat4 matModel; vec4 colDiffuse; vec4 fb; vec4 texSize; vec4 uSat; vec4 uTint; vec4 uVoid; vec4 uHudPx; vec4 uDpi; };
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
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
void main() {
	vec2 ts = texSize.xy;
	vec2 px = 1.0 / ts;
	vec2 uv = v_uv;
	vec2 frag = vec2(gl_FragCoord.x, fb.y - gl_FragCoord.y);

	vec3 col = texture(texture0, uv).rgb;
	float l_center = luma(col);

	float lx = luma(texture(texture0, uv + vec2(px.x, 0.0)).rgb)
	         - luma(texture(texture0, uv - vec2(px.x, 0.0)).rgb);
	float ly = luma(texture(texture0, uv + vec2(0.0, px.y)).rgb)
	         - luma(texture(texture0, uv - vec2(0.0, px.y)).rgb);
	float grad = sqrt(lx * lx + ly * ly);
	float edge = smoothstep(0.16, 0.58, grad);
	col *= 1.0 - edge * 0.24;
	col = mix(vec3(l_center), col, 1.0 + edge * 0.28);

	float grain = value_noise(frag * 0.85) * 0.6 + value_noise(frag * 2.17 + 7.0) * 0.4;
	col *= 1.0 + (grain - 0.5) * (0.075 - 0.025 * l_center);

	vec3 bloom = vec3(0.0);
	bloom += max(texture(texture0, uv + vec2(px.x * 3.0, 0.0)).rgb - 0.86, 0.0);
	bloom += max(texture(texture0, uv - vec2(px.x * 3.0, 0.0)).rgb - 0.86, 0.0);
	bloom += max(texture(texture0, uv + vec2(0.0, px.y * 3.0)).rgb - 0.86, 0.0);
	bloom += max(texture(texture0, uv - vec2(0.0, px.y * 3.0)).rgb - 0.86, 0.0);
	bloom += max(texture(texture0, uv + vec2(px.x * 2.0, px.y * 2.0)).rgb - 0.86, 0.0) * 0.5;
	bloom += max(texture(texture0, uv - vec2(px.x * 2.0, px.y * 2.0)).rgb - 0.86, 0.0) * 0.5;
	col += bloom * 0.42;

	vec3 shadow_tint = vec3(0.94, 0.98, 1.05);
	vec3 light_tint = vec3(1.04, 1.01, 0.95);
	col *= mix(shadow_tint, light_tint, smoothstep(0.08, 0.58, l_center));
	col += vec3(0.008, 0.007, 0.005) * smoothstep(0.06, 0.25, l_center);

	float lg = luma(col);
	col = mix(vec3(lg), col, uSat.x) * uTint.xyz;

	col = mix(uVoid.xyz, col, smoothstep(0.015, 0.11, l_center));

	float hud = uHudPx.x;
	float dpi = uDpi.x;
	if (hud > 0.0) {
		float y = frag.y;
		float shade = 1.0 - smoothstep(hud, hud + 110.0 * dpi, y);
		col *= 1.0 - 0.42 * shade * shade;
		float top_shade = 1.0 - smoothstep(0.0, 70.0 * dpi, ts.y * dpi - y);
		col *= 1.0 - 0.22 * top_shade;
	}

	float vignette = 1.0 - 0.24 * pow(clamp(length(uv - 0.5) * 1.32, 0.0, 1.0), 2.0);
	col *= vignette;

	o_color = vec4(clamp(col, 0.0, 1.0), 1.0) * colDiffuse * v_col;
}
