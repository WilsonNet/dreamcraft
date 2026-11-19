// Quickshell ClipRRect shader: clips sampled textures (minimap, model turntable)
// to a smooth anti-aliased rounded rectangle with an inner border and top glass rim.
#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform vec2 u_size;
uniform vec4 u_uv_rect;
uniform float u_radius;
uniform float u_border_w;
uniform vec4 u_border_col;
uniform float u_rim_alpha;

out vec4 finalColor;

float sd_round(vec2 p, vec2 b, float r)
{
    float rad = clamp(r, 0.0, min(b.x, b.y));
    vec2 q = abs(p) - b + vec2(rad);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - rad;
}

void main()
{
    vec2 uv_span = u_uv_rect.zw - u_uv_rect.xy;
    vec2 norm_uv = vec2(
        abs(uv_span.x) > 1e-5 ? (fragTexCoord.x - u_uv_rect.x) / uv_span.x : 0.5,
        abs(uv_span.y) > 1e-5 ? (fragTexCoord.y - u_uv_rect.y) / uv_span.y : 0.5
    );
    vec2 half_size = max(u_size * 0.5, vec2(1.0));
    vec2 p = (norm_uv - 0.5) * u_size;

    float d = sd_round(p, half_size, u_radius);
    float aa = max(fwidth(d), 0.45);
    float mask = clamp(0.5 - d / aa, 0.0, 1.0);

    vec4 tex_col = texture(texture0, fragTexCoord) * colDiffuse * fragColor;
    vec3 rgb = tex_col.rgb;
    float a = tex_col.a;

    if (u_rim_alpha > 0.002)
    {
        float rim_y = smoothstep(-0.05, 0.65, -p.y / half_size.y);
        float rim_band = smoothstep(-(u_border_w + 1.6), -(u_border_w + 0.3), d) *
                         (1.0 - smoothstep(-max(u_border_w * 0.5, 0.3), 0.25, d));
        rgb += vec3(0.94, 0.97, 0.90) * (rim_band * rim_y * u_rim_alpha);
    }

    if (u_border_w > 0.05 && u_border_col.a > 0.002)
    {
        float inner_mask = clamp(0.5 - (d + u_border_w) / aa, 0.0, 1.0);
        float b_mix = clamp(1.0 - inner_mask, 0.0, 1.0) * u_border_col.a;
        rgb = mix(rgb, u_border_col.rgb, b_mix);
        a = max(a, b_mix);
    }

    finalColor = vec4(clamp(rgb, 0.0, 1.0), clamp(a * mask, 0.0, 1.0));
}
