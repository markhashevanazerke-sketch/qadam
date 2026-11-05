shader_type spatial;
render_mode cull_disabled;
uniform sampler2D original_atlas : source_color, filter_linear_mipmap;
uniform vec4 original_color : source_color = vec4(1.0);
uniform vec4 paint : source_color = vec4(0.3,0.6,0.6,1.0);
void fragment() {
    vec4 tex=texture(original_atlas,UV)*original_color;
    // Only replace the saturated blue painted panels; glass, lights and tyres retain their atlas.
    float maximum=max(max(tex.r,tex.g),tex.b);
    float minimum=min(min(tex.r,tex.g),tex.b);
    float blue=step(tex.r*1.35,tex.b)*step(tex.g*1.13,tex.b)*step(0.09,maximum)*step(0.07,maximum-minimum);
    ALBEDO=mix(tex.rgb,paint.rgb*clamp(maximum*2.3,0.35,1.0),blue);
    ROUGHNESS=0.78;
}
