#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uAmount;
uniform sampler2D uTexture;
out vec4 fragColor;
vec4 tex(vec2 p){ return texture(uTexture, clamp(p, vec2(0.0), vec2(1.0))); }
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 off = vec2(uAmount * 0.012, 0.0);
  float l = dot(tex(uv - off).rgb, vec3(0.299, 0.587, 0.114));
  vec2 rg = tex(uv + off).rg;
  fragColor = vec4(rg.r, rg.g, l, tex(uv).a);
}
