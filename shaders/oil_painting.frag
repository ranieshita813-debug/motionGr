#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uBrightness;
uniform sampler2D uTexture;
out vec4 fragColor;
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec3 c0 = texture(uTexture, clamp(uv + vec2(-1.0, 0.0) / uSize * 2.0, vec2(0.0), vec2(1.0))).rgb;
  vec3 c1 = texture(uTexture, clamp(uv + vec2(1.0, 0.0) / uSize * 2.0, vec2(0.0), vec2(1.0))).rgb;
  vec3 c2 = texture(uTexture, clamp(uv + vec2(0.0, -1.0) / uSize * 2.0, vec2(0.0), vec2(1.0))).rgb;
  vec3 c3 = texture(uTexture, clamp(uv + vec2(0.0, 1.0) / uSize * 2.0, vec2(0.0), vec2(1.0))).rgb;
  vec3 c4 = texture(uTexture, uv).rgb;
  vec3 avg = (c0 + c1 + c2 + c3 + c4 * 2.0) / 6.0;
  float q = 6.0;
  avg = floor(avg * q + 0.5) / q;
  avg += uBrightness * 0.15;
  fragColor = vec4(avg, texture(uTexture, uv).a);
}
