shader_type spatial;
uniform sampler2D source_atlas : source_color;
uniform sampler2D upper_symbol : source_color;
uniform sampler2D lower_symbol : source_color;
uniform int signal_state = 0;
uniform bool auxiliary = false;
varying vec3 local_position;
void vertex() { local_position=VERTEX; }
void fragment() {
 vec3 base=texture(source_atlas,UV).rgb;
 float top_y=auxiliary ? .02053125 : .477625;
 float bottom_y=auxiliary ? -.02053125 : .3955;
 float face_x=auxiliary ? -.0375 : -.05;
 float upper=1.0-step(.0156,length(vec2(local_position.y-top_y,local_position.z)));
 float middle=auxiliary ? 0.0 : 1.0-step(.0156,length(vec2(local_position.y-.4365625,local_position.z)));
 float lower=1.0-step(.0156,length(vec2(local_position.y-bottom_y,local_position.z)));
 float face=1.0-step(.001,abs(local_position.x-face_x));
 float lens=face*max(max(upper,middle),lower);
 vec3 color=upper*vec3(1.,.028,.012)+middle*vec3(1.,.45,.01)+lower*vec3(.025,1.,.22);
 float active=signal_state==0 ? upper : (signal_state==1 ? middle : lower);
 float symbol=1.0;
 if(auxiliary) {
  float center=upper>.5 ? top_y : bottom_y;
  vec2 icon_uv=vec2(local_position.z/.0312+.5,.5-(local_position.y-center)/.0312);
  symbol=upper>.5 ? texture(upper_symbol,icon_uv).a : texture(lower_symbol,icon_uv).a;
 }
 if(auxiliary || local_position.y>.35) {base=vec3(.045,.055,.064);}
 ALBEDO=mix(base,color*mix(.025,.9,active)*symbol,lens);
 EMISSION=color*active*face*symbol*.85;
 ROUGHNESS=.72;
}
