#version 460 core
#include <flutter/runtime_effect.glsl>
// Original Flutter adaptation of Aurora's anchored-color / warped-SDF approach.
// Audio energy increases both wave density and depth independently on each edge.
uniform vec2 uSize;
uniform float uTime;
uniform float uLevel;
uniform float uFrequency;
uniform vec4 uEdges; // top, right, bottom, left: normalized directional energy
uniform float uActive;
uniform float uIntro;
out vec4 fragColor;

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
  vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
  return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
vec3 palette(float i) {
  if(i<0.5) return vec3(0.28,0.22,1.0);
  if(i<1.5) return vec3(1.0,0.19,0.58);
  if(i<2.5) return vec3(1.0,0.53,0.22);
  return vec3(0.12,0.85,1.0);
}
void main() {
  vec2 xy=FlutterFragCoord().xy;
  vec2 uv=xy/uSize;
  vec2 q=abs(xy-uSize*0.5)-(uSize*0.5-vec2(22.0));
  float sdf=length(max(q,0.0))+min(max(q.x,q.y),0.0)-22.0;
  vec4 distances=vec4(xy.y,uSize.x-xy.x,uSize.y-xy.y,xy.x);
  vec4 weights=exp(-distances/38.0);
  float energy=dot(weights,uEdges)/max(dot(weights,vec4(1.0)),0.001);
  float density=5.0+energy*19.0+uFrequency*8.0;
  vec2 npos=xy/min(uSize.x,uSize.y);
  float t=uTime*0.35;
  float waves=noise(npos*density+vec2(t,-t*1.3));
  waves+=0.45*noise(npos*density*2.2-vec2(t*1.8,t));
  float burst=1.0+0.55*exp(-uIntro*1.8)*cos(uIntro*8.2);
  float width=(14.0+energy*27.0+uLevel*7.0)*burst;
  float warped=sdf+(waves-0.25)*width*(0.3+energy*1.2);
  float d=min(abs(sdf),abs(warped));
  float core=1.0-smoothstep(1.5,4.5,d);
  float mid=0.55*(1.0-smoothstep(0.0,width*0.6,d));
  float wide=0.18*(1.0-smoothstep(0.0,width*2.2,d));
  vec3 color=vec3(0.2,0.14,0.6);
  for(int i=0;i<11;i++) {
    float fi=float(i);
    vec2 anchor=vec2(0.5)+vec2(sin(t*(0.31+fi*0.013)+fi*1.3),cos(t*(0.27+fi*0.009)+fi*1.7))*0.56;
    float fall=clamp(1.0-length((uv-anchor)*vec2(uSize.x/uSize.y,1.0))/0.72,0.0,1.0);
    color=mix(color,palette(mod(fi,4.0)),fall*fall*(3.0-2.0*fall));
  }
  float alpha=clamp(core+mid+wide,0.0,1.0)*uActive;
  fragColor=vec4(color*alpha,alpha);
}
