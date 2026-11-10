#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uLevels;
uniform float uIntensity;
uniform sampler2D uTexture;
out vec4 fragColor;
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec4 s = texture(uTexture, uv);
  float levels = max(2.0, floor(uLevels));
  vec3 p = floor(s.rgb * levels) / (levels - 1.0);
  fragColor = vec4(mix(s.rgb, p, clamp(uIntensity, 0.0, 1.0)), s.a);
}
