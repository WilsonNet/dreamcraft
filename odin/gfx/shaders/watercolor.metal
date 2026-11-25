// Watercolour post-process at full resolution (port of assets/shaders/watercolor.fs).
// gl_FragCoord is bottom-up in GL; fb.y turns Metal's top-down position into it.
#include <metal_stdlib>
using namespace metal;

struct U {
	float4x4 mvp;
	float4x4 matModel;
	float4 colDiffuse;
	float4 fb;
	float4 texSize;
	float4 uSat;
	float4 uTint;
	float4 uVoid;
	float4 uHudPx;
	float4 uDpi;
};

struct VIn {
	float3 pos [[attribute(0)]];
	float2 uv  [[attribute(1)]];
	float4 col [[attribute(3)]];
};

struct VOut {
	float4 pos [[position]];
	float2 uv;
	float4 col;
};

vertex VOut vs_main(VIn in [[stage_in]], constant U& u [[buffer(0)]]) {
	VOut o;
	o.pos = u.mvp * float4(in.pos, 1.0);
	o.uv = in.uv;
	o.col = in.col;
	return o;
}

static float hash12(float2 p) {
	return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float value_noise(float2 p) {
	float2 i = floor(p);
	float2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + float2(1.0, 0.0));
	float c = hash12(i + float2(0.0, 1.0));
	float d = hash12(i + float2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

static float luma(float3 c) {
	return dot(c, float3(0.299, 0.587, 0.114));
}

fragment float4 fs_main(VOut in [[stage_in]], constant U& u [[buffer(0)]],
                        texture2d<float> texture0 [[texture(0)]], sampler s0 [[sampler(0)]]) {
	float2 texSize = u.texSize.xy;
	float2 px = 1.0 / texSize;
	float2 uv = in.uv;
	float2 frag = float2(in.pos.x, u.fb.y - in.pos.y);

	float3 col = texture0.sample(s0, uv).rgb;
	float l_center = luma(col);

	float lx = luma(texture0.sample(s0, uv + float2(px.x, 0.0)).rgb)
	         - luma(texture0.sample(s0, uv - float2(px.x, 0.0)).rgb);
	float ly = luma(texture0.sample(s0, uv + float2(0.0, px.y)).rgb)
	         - luma(texture0.sample(s0, uv - float2(0.0, px.y)).rgb);
	float grad = sqrt(lx * lx + ly * ly);
	float edge = smoothstep(0.16, 0.58, grad);
	col *= 1.0 - edge * 0.24;
	col = mix(float3(l_center), col, 1.0 + edge * 0.28);

	float grain = value_noise(frag * 0.85) * 0.6 + value_noise(frag * 2.17 + 7.0) * 0.4;
	col *= 1.0 + (grain - 0.5) * (0.075 - 0.025 * l_center);

	float3 bloom = float3(0.0);
	bloom += max(texture0.sample(s0, uv + float2(px.x * 3.0, 0.0)).rgb - 0.86, 0.0);
	bloom += max(texture0.sample(s0, uv - float2(px.x * 3.0, 0.0)).rgb - 0.86, 0.0);
	bloom += max(texture0.sample(s0, uv + float2(0.0, px.y * 3.0)).rgb - 0.86, 0.0);
	bloom += max(texture0.sample(s0, uv - float2(0.0, px.y * 3.0)).rgb - 0.86, 0.0);
	bloom += max(texture0.sample(s0, uv + float2(px.x * 2.0, px.y * 2.0)).rgb - 0.86, 0.0) * 0.5;
	bloom += max(texture0.sample(s0, uv - float2(px.x * 2.0, px.y * 2.0)).rgb - 0.86, 0.0) * 0.5;
	col += bloom * 0.42;

	float3 shadow_tint = float3(0.94, 0.98, 1.05);
	float3 light_tint = float3(1.04, 1.01, 0.95);
	col *= mix(shadow_tint, light_tint, smoothstep(0.08, 0.58, l_center));
	col += float3(0.008, 0.007, 0.005) * smoothstep(0.06, 0.25, l_center);

	float lg = luma(col);
	col = mix(float3(lg), col, u.uSat.x) * u.uTint.xyz;

	col = mix(u.uVoid.xyz, col, smoothstep(0.015, 0.11, l_center));

	float hud = u.uHudPx.x;
	float dpi = u.uDpi.x;
	if (hud > 0.0) {
		float y = frag.y;
		float shade = 1.0 - smoothstep(hud, hud + 110.0 * dpi, y);
		col *= 1.0 - 0.42 * shade * shade;
		float top_shade = 1.0 - smoothstep(0.0, 70.0 * dpi, texSize.y * dpi - y);
		col *= 1.0 - 0.22 * top_shade;
	}

	float vignette = 1.0 - 0.24 * pow(clamp(length(uv - 0.5) * 1.32, 0.0, 1.0), 2.0);
	col *= vignette;

	return float4(clamp(col, 0.0, 1.0), 1.0) * u.colDiffuse * in.col;
}
