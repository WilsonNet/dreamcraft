// Default program (raylib's default shader): texture0 * colDiffuse * vertex colour.
#include <metal_stdlib>
using namespace metal;

struct U {
	float4x4 mvp;
	float4x4 matModel;
	float4 colDiffuse;
	float4 fb;
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

fragment float4 fs_main(VOut in [[stage_in]], constant U& u [[buffer(0)]],
                        texture2d<float> texture0 [[texture(0)]], sampler s0 [[sampler(0)]]) {
	return texture0.sample(s0, in.uv) * u.colDiffuse * in.col;
}
