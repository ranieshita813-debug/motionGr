#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uAmount;
uniform float uSpeed;
uniform sampler2D uTexture;
out vec4 fragColor;
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 c = uv - 0.5;
  float r = length(c);
  float wave = sin(18.0 * r - uTime * 4.0 * uSpeed) * 0.01 * uAmount * smoothstep(0.0, 0.8, r);
  vec2 dir = r > 0.0001 ? c / r : vec2(0.0);
  vec2 p = uv + dir * wave;
  vec4 col = texture(uTexture, clamp(p, vec2(0.0), vec2(1.0)));
  float pulse = 0.03 * uAmount * sin(10.0 * r - uTime * 3.0 * uSpeed);
  fragColor = vec4(col.rgb + pulse, col.a);
}
