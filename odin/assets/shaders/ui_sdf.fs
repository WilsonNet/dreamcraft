// Batched Quickshell-inspired UI SDF fragment shader:
// Analytical 4-corner rounded boxes, soft outer shadow, anti-aliased inner border,
// top specular glass rim hairline, InkWell click ripples, and rounded progress bars.
#version 330

flat in int v_slot;
in vec2 v_local;
in vec4 v_color;

uniform sampler2D texture0;

out vec4 finalColor;

float sd_rounded_box(vec2 p, vec2 b, vec4 r)
{
    vec2 rs = (p.x > 0.0) ? vec2(r.y, r.z) : vec2(r.x, r.w);
    float rad = clamp((p.y > 0.0) ? rs.y : rs.x, 0.0, min(b.x, b.y));
    vec2 q = abs(p) - b + vec2(rad);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - rad;
}

vec4 fetch_row(int row)
{
    return texelFetch(texture0, ivec2(v_slot, row), 0);
}

void main()
{
    vec4 r0 = fetch_row(0);
    vec4 border_col = fetch_row(1);
    vec4 r2 = fetch_row(2);
    vec4 r3 = fetch_row(3);
    vec4 shadow_col = fetch_row(4);
    vec4 r5 = fetch_row(5);
    vec4 r6 = fetch_row(6);
    vec4 accent_col = fetch_row(7);

    vec4 radii = r0 * 255.0;
    float hw = (floor(r2.r * 255.0 + 0.5) * 256.0 + floor(r2.g * 255.0 + 0.5)) * 0.25;
    float hh = (floor(r2.b * 255.0 + 0.5) * 256.0 + floor(r2.a * 255.0 + 0.5)) * 0.25;
    vec2 half_size = max(vec2(hw, hh), vec2(0.5));

    float border_w = r3.r * (255.0 / 16.0);
    float top_rim = r3.g;
    float shadow_blur = r3.b * 64.0;
    float shadow_off_y = (r3.a * 255.0 - 128.0) * 0.5;

    float prog_ratio = r6.r;
    int mode = int(floor(r6.g * 255.0 + 0.5));
    float state_lift = r6.a;

    vec2 p = v_local;
    float d = sd_rounded_box(p, half_size, radii);
    float aa = max(fwidth(d), 0.45);
    float fill_mask = clamp(0.5 - d / aa, 0.0, 1.0);

    // 1. Soft elevation shadow behind the card
    vec4 out_col = vec4(0.0);
    if (shadow_col.a > 0.002 && shadow_blur > 0.1)
    {
        float sd = sd_rounded_box(p - vec2(0.0, shadow_off_y), half_size, radii);
        float spread = clamp(1.0 - smoothstep(-shadow_blur * 0.15, shadow_blur, sd), 0.0, 1.0);
        float sa = pow(spread, 1.7) * shadow_col.a;
        out_col = vec4(shadow_col.rgb, sa);
    }

    // 2. Interior body color + optional progress pill fill + click ripple
    vec3 body_rgb = v_color.rgb + vec3(0.08, 0.10, 0.07) * state_lift;
    float body_a = v_color.a;

    if (mode == 1 && prog_ratio > 0.004)
    {
        float fill_right = -half_size.x + (half_size.x * 2.0) * clamp(prog_ratio, 0.0, 1.0);
        float prog_edge = clamp(0.5 - (p.x - fill_right) / max(fwidth(p.x), 0.72), 0.0, 1.0);
        float sheen = clamp(0.5 - (p.y / half_size.y) * 0.5, 0.0, 1.0);
        vec3 bar_rgb = accent_col.rgb * mix(0.86, 1.10, sheen);
        body_rgb = mix(body_rgb, bar_rgb, prog_edge * accent_col.a);
        body_a = max(body_a, prog_edge * accent_col.a);
    }

    float ripple_a = r5.a;
    if (ripple_a > 0.002)
    {
        vec2 uv = p / half_size;
        vec2 r_center = r5.rg * 2.0 - 1.0;
        float aspect = half_size.x / max(half_size.y, 1.0);
        vec2 dv = (uv - r_center) * vec2(aspect, 1.0);
        float dist = length(dv);
        float rad = r5.b * max(aspect, 1.0) * 1.45;
        float r_mask = 1.0 - smoothstep(max(rad - 0.18, 0.0), rad + 0.06, dist);
        vec3 r_rgb = mix(vec3(0.95, 0.96, 0.90), accent_col.rgb, 0.45);
        body_rgb = mix(body_rgb, r_rgb, r_mask * ripple_a * 0.42);
    }

    // 3. Torchlit gold-leaf top specular rim + medieval inner filigree double-rule & corner diamonds
    if (top_rim > 0.002)
    {
        float rim_y = smoothstep(-0.05, 0.70, -p.y / half_size.y);
        float rim_band = smoothstep(-(border_w + 1.9), -(border_w + 0.35), d) *
                         (1.0 - smoothstep(-max(border_w * 0.5, 0.4), 0.25, d));
        vec3 rim_tint = mix(border_col.rgb, vec3(1.0, 0.89, 0.64), 0.58);
        body_rgb += rim_tint * (rim_band * rim_y * top_rim * 1.15);
    }

    if (mode == 0 && border_w >= 0.75 && min(half_size.x, half_size.y) >= 13.0)
    {
        float d_fil = abs(d + border_w + 2.6) - 0.35;
        float fil_mask = clamp(0.5 - d_fil / aa, 0.0, 1.0);
        vec3 fil_rgb = mix(border_col.rgb, vec3(0.96, 0.82, 0.48), 0.38);
        float fil_a = (min(half_size.x, half_size.y) >= 24.0 ? 0.34 : 0.22) * border_col.a;
        body_rgb = mix(body_rgb, fil_rgb, fil_mask * fil_a);

        if (min(half_size.x, half_size.y) >= 24.0)
        {
            vec2 cp = half_size - abs(p) - vec2(border_w + 6.0);
            float d_gem = abs(cp.x) + abs(cp.y) - 2.1;
            float gem_mask = clamp(0.5 - d_gem / aa, 0.0, 1.0);
            body_rgb = mix(body_rgb, vec3(0.97, 0.84, 0.50), gem_mask * 0.52 * border_col.a);
        }
    }

    // 4. Crisp interior brass border
    vec4 card = vec4(body_rgb, body_a);
    if (border_w > 0.05 && border_col.a > 0.002)
    {
        float inner_mask = clamp(0.5 - (d + border_w) / aa, 0.0, 1.0);
        float border_mix = clamp(1.0 - inner_mask, 0.0, 1.0) * border_col.a;
        card.rgb = mix(card.rgb, border_col.rgb, border_mix);
        card.a = max(card.a, border_mix);
    }
    card.a *= fill_mask;

    // 5. Composite card over shadow using straight-alpha Over operator
    float inv_a = 1.0 - card.a;
    float comb_a = card.a + out_col.a * inv_a;
    vec3 comb_rgb = (comb_a > 0.0005)
        ? (card.rgb * card.a + out_col.rgb * out_col.a * inv_a) / comb_a
        : vec3(0.0);

    finalColor = vec4(clamp(comb_rgb, 0.0, 1.0), clamp(comb_a, 0.0, 1.0));
}
