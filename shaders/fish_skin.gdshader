shader_type spatial;
uniform vec3 back_color : source_color = vec3(.19,.25,.21);
uniform vec3 model_min;
uniform vec3 model_size;
uniform float swim_time = 0.0;
uniform int pattern = 0;
varying vec3 body_uv;
void vertex() {
    body_uv = (VERTEX-model_min)/max(model_size,vec3(.001));
    float tail = 1.0-smoothstep(.05,.70,body_uv.z);
    VERTEX.x += sin(swim_time-body_uv.z*4.0)*tail*tail*model_size.z*.035;
}
void fragment() {
    vec3 belly = vec3(.57,.59,.48);
    vec3 color = mix(belly,back_color,smoothstep(.20,.70,body_uv.y));
    float stripe = sin(body_uv.z*55.0+body_uv.y*4.0);
    if (pattern == 1) { color *= 1.0-smoothstep(.65,.95,stripe)*.28; }
    if (pattern == 2) { color = mix(color,color*.55,(1.0-smoothstep(.025,.06,abs(body_uv.y-.51)))*.5); }
    ALBEDO = color;
    ROUGHNESS = .36;
    METALLIC = .18;
    SPECULAR = .65;
}
