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
  float l = dot(s.rgb, vec3(0.299, 0.587, 0.114));
  vec3 dark = vec3(0.05, 0.0, 0.25);
  vec3 light = vec3(1.0, 0.2, 0.6);
  vec3 duo = mix(dark, light, smoothstep(0.0, 1.0, l));
  fragColor = vec4(mix(s.rgb, duo, clamp(uIntensity, 0.0, 1.0)), s.a);
}
