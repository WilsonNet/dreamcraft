// Painterly units and props (port of assets/shaders/unit.{vs,fs}).
#include <metal_stdlib>
using namespace metal;

struct U {
	float4x4 mvp;
	float4x4 matModel;
	float4 colDiffuse;
	float4 fb;
	float4 u_camera;
	float4 u_key_dir;
	float4 u_time;
	float4 u_tint;
	float4 u_fog_vis;
};

struct VIn {
	float3 pos [[attribute(0)]];
	float2 uv  [[attribute(1)]];
	float3 nrm [[attribute(2)]];
	float4 col [[attribute(3)]];
};

struct VOut {
	float4 pos [[position]];
	float3 world;
	float3 normal;
	float4 albedo;
	float2 look;
};

vertex VOut vs_main(VIn in [[stage_in]], constant U& u [[buffer(0)]]) {
	VOut o;
	float4 world = u.matModel * float4(in.pos, 1.0);
	o.world = world.xyz;
	// transpose(inverse(m)) up to scale: the cofactor matrix (normalised in the fragment)
	float3 c0 = u.matModel[0].xyz;
	float3 c1 = u.matModel[1].xyz;
	float3 c2 = u.matModel[2].xyz;
	float3x3 cof = float3x3(cross(c1, c2), cross(c2, c0), cross(c0, c1));
	o.normal = cof * in.nrm;
	o.albedo = in.col;
	o.look = in.uv;
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

fragment float4 fs_main(VOut in [[stage_in]], constant U& u [[buffer(0)]]) {
	float3 N = normalize(in.normal);
	float3 V = normalize(u.u_camera.xyz - in.world);
	if (dot(N, V) < 0.0) {
		N = -N;
	}

	float ao = clamp(in.albedo.a, 0.0, 1.0);
	float metal = clamp(in.look.x, 0.0, 1.0);
	float glow = clamp(in.look.y, 0.0, 1.0);
	float3 albedo = in.albedo.rgb * u.u_tint.xyz;

	float3 L = normalize(u.u_key_dir.xyz);
	float3 F = normalize(float3(-0.62, 0.34, 0.70));
	float ndl = dot(N, L);
	float ndv = clamp(dot(N, V), 0.0, 1.0);

	float key = smoothstep(-0.22, 0.86, ndl);
	float fill = (dot(N, F) * 0.5 + 0.5) * 0.24;
	float sky = 0.12 + 0.10 * clamp(N.y, 0.0, 1.0);
	float wash = (value_noise(in.world.xz * 7.5 + in.world.y * 4.5) - 0.5) * 0.085;
	float lv = clamp(key * 0.78 + fill + sky * 0.65 + wash - (1.0 - ao) * 0.18, 0.0, 1.0);

	float t1 = smoothstep(0.20, 0.28, lv);
	float t2 = smoothstep(0.44, 0.52, lv);
	float t3 = smoothstep(0.74, 0.82, lv);

	float3 c0 = albedo * float3(0.44, 0.46, 0.68);
	float3 c1 = albedo * float3(0.68, 0.70, 0.86);
	float3 c2 = albedo * float3(1.00, 0.99, 0.96);
	float3 c3 = mix(albedo * float3(1.12, 1.07, 0.93), float3(1.00, 0.97, 0.88), 0.14);

	float3 col = mix(c0, c1, t1);
	col = mix(col, c2, t2);
	col = mix(col, c3, t3);

	float tp = (lv - 0.48) / 0.055;
	float term_pool = exp(-(tp * tp));
	col *= 1.0 - term_pool * 0.06;
	col *= mix(0.76, 1.03, ao);

	float3 H = normalize(L + V);
	float spec_pow = mix(28.0, 120.0, metal);
	float spec_raw = pow(max(dot(N, H), 0.0), spec_pow);
	float spec = mix(spec_raw * 0.25, smoothstep(0.18, 0.55, spec_raw), step(0.25, metal));
	col += float3(1.00, 0.96, 0.86) * spec * (0.04 + 0.34 * metal) * (0.35 + 0.65 * t2) * ao;

	float grazing = 1.0 - ndv;
	float silhouette = smoothstep(0.55, 0.96, grazing);
	float3 rim_warm = float3(1.00, 0.84, 0.54);
	float3 rim_cool = float3(0.48, 0.66, 0.94);
	float3 rim = mix(rim_cool, rim_warm, smoothstep(-0.10, 0.82, ndl));
	col = mix(col, col * float3(0.44, 0.42, 0.56), silhouette * 0.40);
	col += rim * smoothstep(0.50, 0.92, grazing) * (0.10 + 0.14 * ao);

	float vis = clamp(u.u_fog_vis.x, 0.0, 1.0);
	float pulse = 0.86 + 0.14 * sin(u.u_time.x * 2.4 + in.world.y * 5.0);
	col += albedo * glow * (1.25 * pulse + 0.55) * vis;

	float grey = dot(col, float3(0.299, 0.587, 0.114));
	col = mix(float3(grey), col, 1.10);

	float3 fog_mem = mix(float3(grey), col, 0.52) * float3(0.32, 0.41, 0.53) + float3(0.014, 0.022, 0.034);
	col = mix(fog_mem, col, smoothstep(0.36, 1.0, vis));

	return float4(clamp(col, 0.0, 1.0), 1.0);
}
