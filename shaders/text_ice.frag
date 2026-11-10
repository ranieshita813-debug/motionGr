#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uIntensity;
uniform sampler2D uTexture;
out vec4 fragColor;
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec4 s = texture(uTexture, uv);
  float frost = 0.5 + 0.5 * sin(uv.y * 40.0 + uTime);
  vec3 ice = mix(vec3(0.7, 0.9, 1.0), vec3(0.9, 1.0, 1.0), frost);
  ice += 0.15 * uIntensity * vec3(0.4, 0.8, 1.0);
  fragColor = vec4(mix(s.rgb, ice, 0.8), s.a);
}
