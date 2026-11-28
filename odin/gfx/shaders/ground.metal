// Ground plane: painted albedo with bilinear fog-of-war mist (port of assets/shaders/ground.fs).
#include <metal_stdlib>
using namespace metal;

struct U {
	float4x4 mvp;
	float4x4 matModel;
	float4 colDiffuse;
	float4 fb;
	float4 s_time; // x = u_time
};

struct VIn {
	float3 pos [[attribute(0)]];
	float2 uv  [[attribute(1)]];
};

struct VOut {
	float4 pos [[position]];
	float2 uv;
	float3 world;
};

vertex VOut vs_main(VIn in [[stage_in]], constant U& u [[buffer(0)]]) {
	VOut o;
	o.uv = in.uv;
	o.world = (u.matModel * float4(in.pos, 1.0)).xyz;
	o.pos = u.mvp * float4(in.pos, 1.0);
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

static float fbm(float2 p) {
	float v = value_noise(p) * 0.55;
	v += value_noise(p * 2.07 + float2(13.1, 29.3)) * 0.30;
	v += value_noise(p * 4.19 + float2(41.7, 17.9)) * 0.15;
	return v;
}

fragment float4 fs_main(VOut in [[stage_in]], constant U& u [[buffer(0)]],
                        texture2d<float> texture0 [[texture(0)]], sampler s0 [[sampler(0)]],
                        texture2d<float> texture1 [[texture(1)]], sampler s1 [[sampler(1)]]) {
	float t = u.s_time.x;
	float2 wp = in.world.xz;
	float mist_a = fbm(wp * 0.55 + float2(t * 0.025, -t * 0.018));
	float mist_b = fbm(wp * 1.15 + float2(-t * 0.018, t * 0.022) + 7.3);

	float2 mist_disp = (float2(mist_a, mist_b) - 0.5) * float2(1.4 / 128.0, 1.4 / 80.0);
	float fog_raw = texture1.sample(s1, clamp(in.uv + mist_disp, 0.002, 0.998)).r;
	float edge_band = 4.0 * fog_raw * (1.0 - fog_raw);
	float fog_val = clamp(fog_raw + (mist_a - 0.5) * 0.14 * edge_band, 0.0, 1.0);

	float explored_vis = smoothstep(0.08, 0.42, fog_val);
	float active_vis = smoothstep(0.58, 0.92, fog_val);

	float grain = value_noise(wp * 3.8) * 0.6 + value_noise(wp * 9.5 + 4.1) * 0.4;
	float3 albedo = texture0.sample(s0, in.uv).rgb;
	float3 lit = albedo * float3(1.03, 1.01, 0.96) * (1.0 + (grain - 0.5) * 0.045);

	float gd = (in.world.x - 37.05) / 0.26;
	float goal_band = exp(-(gd * gd));
	float shimmer_wave = 0.55 + 0.45 * sin(in.world.z * 1.6 - t * 1.9 + mist_b * 4.0);
	lit += float3(0.24, 0.19, 0.06) * goal_band * shimmer_wave;

	float lum = dot(lit, float3(0.299, 0.587, 0.114));
	float3 moonlit = mix(float3(lum), lit, 0.52) * float3(0.32, 0.41, 0.53) + float3(0.015, 0.024, 0.036);
	float3 ground_col = mix(moonlit, lit, active_vis);

	float3 void_col = float3(0.032, 0.052, 0.052);
	float edge_x = smoothstep(0.0, 0.018, in.uv.x) * smoothstep(0.0, 0.018, 1.0 - in.uv.x);
	float edge_y = smoothstep(0.0, 0.024, in.uv.y) * smoothstep(0.0, 0.024, 1.0 - in.uv.y);
	float vis_world = explored_vis * edge_x * edge_y;
	float mist_edge = vis_world * (1.0 - vis_world) * 4.0;
	float3 col = mix(void_col, ground_col, vis_world);
	col += float3(0.020, 0.034, 0.040) * mist_edge * (0.65 + 0.35 * mist_a);

	return float4(clamp(col, 0.0, 1.0), 1.0);
}
