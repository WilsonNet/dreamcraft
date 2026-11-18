// Ground plane fragment shader: blends high-res painted albedo with bilinear
// fog-of-war mist, moonlit explored memory, sunlit grain, and goal shimmer.
#version 330

in vec2 fragTexCoord;
in vec3 fragWorldPos;

uniform sampler2D texture0;
uniform sampler2D texture1;
uniform float u_time;

out vec4 finalColor;

float hash12(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p)
{
    float v = value_noise(p) * 0.55;
    v += value_noise(p * 2.07 + vec2(13.1, 29.3)) * 0.30;
    v += value_noise(p * 4.19 + vec2(41.7, 17.9)) * 0.15;
    return v;
}

void main()
{
    vec2 wp = fragWorldPos.xz;
    float mist_a = fbm(wp * 0.55 + vec2(u_time * 0.025, -u_time * 0.018));
    float mist_b = fbm(wp * 1.15 + vec2(-u_time * 0.018, u_time * 0.022) + 7.3);

    vec2 mist_disp = (vec2(mist_a, mist_b) - 0.5) * vec2(1.4 / 80.0, 1.4 / 50.0);
    float fog_raw = texture(texture1, clamp(fragTexCoord + mist_disp, 0.002, 0.998)).r;
    float edge_band = 4.0 * fog_raw * (1.0 - fog_raw);
    float fog_val = clamp(fog_raw + (mist_a - 0.5) * 0.14 * edge_band, 0.0, 1.0);

    float explored_vis = smoothstep(0.08, 0.42, fog_val);
    float active_vis = smoothstep(0.58, 0.92, fog_val);

    float grain = value_noise(wp * 3.8) * 0.6 + value_noise(wp * 9.5 + 4.1) * 0.4;
    vec3 albedo = texture(texture0, fragTexCoord).rgb;
    vec3 lit = albedo * vec3(1.03, 1.01, 0.96) * (1.0 + (grain - 0.5) * 0.045);

    float goal_band = exp(-pow((fragWorldPos.x - 37.05) / 0.26, 2.0));
    float shimmer_wave = 0.55 + 0.45 * sin(fragWorldPos.z * 1.6 - u_time * 1.9 + mist_b * 4.0);
    lit += vec3(0.24, 0.19, 0.06) * goal_band * shimmer_wave;

    float lum = dot(lit, vec3(0.299, 0.587, 0.114));
    vec3 moonlit = mix(vec3(lum), lit, 0.52) * vec3(0.32, 0.41, 0.53) + vec3(0.015, 0.024, 0.036);
    vec3 ground_col = mix(moonlit, lit, active_vis);

    vec3 void_col = vec3(0.032, 0.052, 0.052);
    float edge_x = smoothstep(0.0, 0.018, fragTexCoord.x) * smoothstep(0.0, 0.018, 1.0 - fragTexCoord.x);
    float edge_y = smoothstep(0.0, 0.024, fragTexCoord.y) * smoothstep(0.0, 0.024, 1.0 - fragTexCoord.y);
    float vis_world = explored_vis * edge_x * edge_y;
    float mist_edge = vis_world * (1.0 - vis_world) * 4.0;
    vec3 col = mix(void_col, ground_col, vis_world);
    col += vec3(0.020, 0.034, 0.040) * mist_edge * (0.65 + 0.35 * mist_a);

    finalColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
