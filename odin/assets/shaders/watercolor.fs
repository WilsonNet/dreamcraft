// Watercolour post-process.
//
// Replaces the old pixel-art outline + 12-level posterize that made the scene
// read as voxels. Layers: a small wet bleed, pigment pooling on edges, paper
// granulation, a cheap emissive bloom and a warm/cool split tone.
#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform vec2 texSize;

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

float luma(vec3 c)
{
    return dot(c, vec3(0.299, 0.587, 0.114));
}

void main()
{
    vec2 px = 1.0 / texSize;
    vec2 uv = fragTexCoord;

    // Wet bleed: sample position wobbles slightly, like pigment on damp paper.
    vec2 wobble = vec2(value_noise(uv * 6.0), value_noise(uv * 6.0 + 4.3)) - 0.5;
    vec2 suv = uv + wobble * px * 0.9;

    // Soft wash, five taps at low resolution.
    vec2 step1 = px * 0.8;
    vec3 col = texture(texture0, suv).rgb * 0.56;
    col += texture(texture0, suv + vec2(step1.x, 0.0)).rgb * 0.11;
    col += texture(texture0, suv - vec2(step1.x, 0.0)).rgb * 0.11;
    col += texture(texture0, suv + vec2(0.0, step1.y)).rgb * 0.11;
    col += texture(texture0, suv - vec2(0.0, step1.y)).rgb * 0.11;

    // Pigment pools where tones meet: soft edge darkening plus saturation.
    float l_center = luma(col);
    float lx = luma(texture(texture0, suv + vec2(px.x, 0.0)).rgb)
             - luma(texture(texture0, suv - vec2(px.x, 0.0)).rgb);
    float ly = luma(texture(texture0, suv + vec2(0.0, px.y)).rgb)
             - luma(texture(texture0, suv - vec2(0.0, px.y)).rgb);
    float edge = clamp(sqrt(lx * lx + ly * ly) * 2.1, 0.0, 1.0);
    col *= 1.0 - edge * 0.36;
    col = mix(vec3(l_center), col, 1.0 + edge * 0.45);

    // Paper tooth: fine grain settles into the darker washes.
    float grain = value_noise(gl_FragCoord.xy * 0.82) * 0.6
                + value_noise(gl_FragCoord.xy * 2.13 + 7.0) * 0.4;
    col *= 1.0 + (grain - 0.5) * (0.16 - 0.06 * l_center);

    // Cheap bloom keeps visor and rune glows reading through the wash.
    vec3 bloom = vec3(0.0);
    bloom += max(texture(texture0, suv + vec2(px.x * 4.0, 0.0)).rgb - 0.70, 0.0);
    bloom += max(texture(texture0, suv - vec2(px.x * 4.0, 0.0)).rgb - 0.70, 0.0);
    bloom += max(texture(texture0, suv + vec2(0.0, px.y * 4.0)).rgb - 0.70, 0.0);
    bloom += max(texture(texture0, suv - vec2(0.0, px.y * 4.0)).rgb - 0.70, 0.0);
    col += bloom * 0.38;

    // Split tone: cool pigment in shadow, warm paper in the light.
    vec3 shadow_tint = vec3(0.90, 0.99, 1.08);
    vec3 light_tint = vec3(1.07, 1.01, 0.92);
    col *= mix(shadow_tint, light_tint, smoothstep(0.05, 0.55, l_center));

    // Barely-there paper lift and a soft vignette.
    col = col * 0.97 + vec3(0.014, 0.013, 0.011);
    float vignette = 1.0 - 0.20 * pow(clamp(length(uv - 0.5) * 1.35, 0.0, 1.0), 2.0);
    col *= vignette;

    finalColor = vec4(clamp(col, 0.0, 1.0), 1.0) * colDiffuse * fragColor;
}
