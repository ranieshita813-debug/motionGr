#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uDistortionAmount;
uniform sampler2D uTexture;
out vec4 fragColor;
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 c = uv - 0.5;
  float r = length(c);
  float edge = smoothstep(0.2, 0.75, r);
  float wave = sin(r * 18.0 - uTime * 2.0) * 0.015 * uDistortionAmount * edge;
  vec2 dir = r > 0.0001 ? c / r : vec2(0.0);
  vec2 p = uv + dir * wave;
  fragColor = texture(uTexture, clamp(p, vec2(0.0), vec2(1.0)));
}
