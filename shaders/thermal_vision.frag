#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uContrast;
uniform sampler2D uTexture;
out vec4 fragColor;
vec3 heat(float t) {
  t = clamp(t, 0.0, 1.0);
  if (t < 0.25) return mix(vec3(0.0, 0.0, 0.2), vec3(0.0, 0.2, 1.0), t / 0.25);
  if (t < 0.5) return mix(vec3(0.0, 0.2, 1.0), vec3(0.0, 1.0, 0.2), (t - 0.25) / 0.25);
  if (t < 0.75) return mix(vec3(0.0, 1.0, 0.2), vec3(1.0, 1.0, 0.0), (t - 0.5) / 0.25);
  return mix(vec3(1.0, 1.0, 0.0), vec3(1.0, 0.1, 0.0), (t - 0.75) / 0.25);
}
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec4 s = texture(uTexture, uv);
  float l = dot(s.rgb, vec3(0.299, 0.587, 0.114));
  l = (l - 0.5) * uContrast + 0.5;
  l += 0.03 * sin(uTime * 2.0 + uv.y * 40.0);
  fragColor = vec4(heat(l), s.a);
}
