shader_type sky;
uniform float daylight = 0.0;
uniform float night = 0.0;
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    vec4 h=fract(sin(vec4(dot(i,vec2(127.1,311.7)),dot(i+vec2(1,0),vec2(127.1,311.7)),dot(i+vec2(0,1),vec2(127.1,311.7)),dot(i+vec2(1,1),vec2(127.1,311.7))))*43758.5453);
    return mix(mix(h.x,h.y,f.x),mix(h.z,h.w,f.x),f.y);
}
void sky() {
    float height=max(EYEDIR.y,0.0);
    vec3 horizon=mix(vec3(0.81,0.57,0.48),vec3(0.65,0.80,0.88),daylight);
    vec3 zenith=mix(vec3(0.18,0.32,0.49),vec3(0.18,0.43,0.66),daylight);
    vec3 base=mix(horizon,zenith,pow(height,0.42));
    vec2 p=EYEDIR.xz/max(EYEDIR.y+0.22,0.08)*2.3+vec2(TIME*0.002,0.0);
    float clouds=noise(p)*0.55+noise(p*2.1)*0.28+noise(p*4.3)*0.17;
    float cover=smoothstep(0.54,0.74,clouds)*smoothstep(0.015,0.18,height);
    base=mix(base,mix(vec3(0.66,0.56,0.59),vec3(1.0,0.78,0.60),clouds),cover*0.75);
    vec3 sun_dir=normalize(vec3(-0.65,0.18,-0.74));
    float sun=dot(EYEDIR,sun_dir);
    base+=vec3(1.0,0.50,0.22)*(pow(max(sun,0.0),90.0)*0.20+smoothstep(0.99945,0.9998,sun)*0.8);
    base=mix(base,base*0.13+vec3(0.01,0.02,0.045),night);
    COLOR=mix(vec3(0.36,0.41,0.43),base,smoothstep(-0.15,0.02,EYEDIR.y));
}
