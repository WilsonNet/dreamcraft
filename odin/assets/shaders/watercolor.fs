// Watercolour post-process at native full resolution.
//
// Sharp center tap with zero blurry 5-tap UV smear, high-threshold edge pooling
// ink accent, delicate paper tooth grain, selective emissive bloom, gentle
// warm/cool split tone, and soft vignette.
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

    // Sharp native full-resolution center tap.
    vec3 col = texture(texture0, uv).rgb;
    float l_center = luma(col);

    // High-threshold pigment pooling ink accent along crisp silhouettes/steps.
    float lx = luma(texture(texture0, uv + vec2(px.x, 0.0)).rgb)
             - luma(texture(texture0, uv - vec2(px.x, 0.0)).rgb);
    float ly = luma(texture(texture0, uv + vec2(0.0, px.y)).rgb)
             - luma(texture(texture0, uv - vec2(0.0, px.y)).rgb);
    float grad = sqrt(lx * lx + ly * ly);
    float edge = smoothstep(0.16, 0.58, grad);
    col *= 1.0 - edge * 0.24;
    col = mix(vec3(l_center), col, 1.0 + edge * 0.28);

    // Delicate paper tooth grain.
    float grain = value_noise(gl_FragCoord.xy * 0.85) * 0.6
                + value_noise(gl_FragCoord.xy * 2.17 + 7.0) * 0.4;
    col *= 1.0 + (grain - 0.5) * (0.075 - 0.025 * l_center);

    // Selective bloom for glowing runes, lenses, and brightest specular sparks.
    vec3 bloom = vec3(0.0);
    bloom += max(texture(texture0, uv + vec2(px.x * 3.0, 0.0)).rgb - 0.86, 0.0);
    bloom += max(texture(texture0, uv - vec2(px.x * 3.0, 0.0)).rgb - 0.86, 0.0);
    bloom += max(texture(texture0, uv + vec2(0.0, px.y * 3.0)).rgb - 0.86, 0.0);
    bloom += max(texture(texture0, uv - vec2(0.0, px.y * 3.0)).rgb - 0.86, 0.0);
    bloom += max(texture(texture0, uv + vec2(px.x * 2.0, px.y * 2.0)).rgb - 0.86, 0.0) * 0.5;
    bloom += max(texture(texture0, uv - vec2(px.x * 2.0, px.y * 2.0)).rgb - 0.86, 0.0) * 0.5;
    col += bloom * 0.42;

    // Gentle warm/cool split tone and subtle paper lift above void.
    vec3 shadow_tint = vec3(0.94, 0.98, 1.05);
    vec3 light_tint = vec3(1.04, 1.01, 0.95);
    col *= mix(shadow_tint, light_tint, smoothstep(0.08, 0.58, l_center));
    col += vec3(0.008, 0.007, 0.005) * smoothstep(0.06, 0.25, l_center);

    // Soft vignette.
    float vignette = 1.0 - 0.14 * pow(clamp(length(uv - 0.5) * 1.32, 0.0, 1.0), 2.0);
    col *= vignette;

    finalColor = vec4(clamp(col, 0.0, 1.0), 1.0) * colDiffuse * fragColor;
}
