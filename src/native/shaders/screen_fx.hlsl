// The game's final screen pass, independent of the photo-editor chain.
// Live PS rows c0..c6 and VS rows c240..c247 are captured at the draw.
// t0 is the finished native frame; t2 is the game's vignette gradient;
// t5 is its scrolling noise texture. Literal rows are local to each variant.
// Host row c248.xyz selects explicit base-map LOD for t0/t2/t5, respectively;
// a negative value keeps the shader instruction's computed LOD behavior.
cbuffer Consts : register(b0) { float4 c[256]; };

Texture2D t0 : register(t0);
Texture2D t2 : register(t2);
Texture2D t5 : register(t5);
SamplerState s_lin : register(s0);
SamplerState s_pt : register(s1);
SamplerState s_wrap : register(s2);

float4 SampleScene(float2 uv) {
  float4 result = 0.0;
  if (c[248].x >= 0.0) result = t0.SampleLevel(s_lin, uv, c[248].x);
  else result = t0.Sample(s_lin, uv);
  return result;
}

float4 SampleVignette(float2 uv) {
  float4 result = 0.0;
  if (c[248].y >= 0.0) result = t2.SampleLevel(s_lin, uv, c[248].y);
  else result = t2.Sample(s_lin, uv);
  return result;
}

float4 SampleNoise(float2 uv) {
  float4 result = 0.0;
  if (c[248].z >= 0.0) result = t5.SampleLevel(s_wrap, uv, c[248].z);
  else result = t5.Sample(s_wrap, uv);
  return result;
}

struct VsOut {
  float4 pos : SV_Position;
  float4 r0 : TEXCOORD0;
};

VsOut vs_raw(uint vid : SV_VertexID) {
  VsOut o;
  float2 uv = float2((vid << 1) & 2, vid & 2);
  o.pos = float4(uv * float2(2, -2) + float2(-1, 1), 0, 1);
  o.r0 = float4(uv, uv);
  return o;
}

// postfx_quadTransformVS: sampling UV scale/translation are independent
// of the position transform. The host supplies a fullscreen triangle.
VsOut vs_scaled(uint vid : SV_VertexID) {
  VsOut o = vs_raw(vid);
  o.r0.xy = o.r0.xy * c[243].xy + c[242].xy;
  return o;
}

// postfx_basictex_fisheyePS. The opaque variant has the same RGB math.
float4 LensColor(float4 input_uv) {
  const float4 l254 = float4(-1.0, 0.5, 0.0, 0.0);
  const float4 l255 = float4(-0.5, -0.888888896, 1.0, 1.77777779);
  float4 r0 = input_uv;
  float4 r1 = 0;
  r1.y = c[0].y;
  {
    float old_x = r0.x;
    r0.xyz = float3(old_x * l255.w + l255.y,
                   r0.y * l255.z + l255.x,
                   old_x * l255.z + l255.x);
  }
  r1.x = r0.x * r0.x;
  r1.z = r0.y * r0.y;
  r1.w = r0.z * r0.z;
  {
    float radius_x = r1.x + r1.z;
    float radius_w = r1.w + r1.z;
    r0.x = radius_x;
    r0.w = radius_w;
  }
  r1.x = c[0].x + l255.z;
  r1.z = r0.w * c[1].x;
  r1.w = sqrt(abs(r0.x));
  r1.x = r1.w * (-c[1].z) + r1.x;
  r0.x = r1.z * r0.w + c[1].y;
  {
    float radius = r0.x;
    r0.xy = r0.zy * radius + l254.yy;
  }
  r0 = SampleScene(r0.xy);
  r1 = SampleVignette(r1.xy);
  r1 = saturate(r1 + c[0].w);
  r1 = r1 + l254.x;
  r1 = r1 * c[2].y + l255.z;
  return r1 * r0;
}

float4 ps_opaque(VsOut i) : SV_Target {
  float4 result = LensColor(i.r0);
  result.a = 1.0;
  return result;
}

float4 ps_alpha(VsOut i) : SV_Target {
  return LensColor(i.r0);
}

// postfx_basictex_fisheye_noisePS: its own two scrolling noise fetches and
// dot weights drive the marker-return transition. c4.x scales the scene;
// c4.y scales the saturated noise contribution to all four output channels.
float4 ps_noise(VsOut i) : SV_Target {
  const float4 l253 = float4(1.0, -0.888888896, -1.0, 0.0);
  const float4 l254 = float4(6.625, 11.0, -0.5, 1.77777779);
  const float4 l255 = float4(-2.0, 0.5, 5.625, 10.0);
  float4 r0 = i.r0;
  float4 r1 = 0;
  float4 r2 = 0;
  float4 r3 = 0;
  float4 r4 = 0;

  r1.xy = r0.xy * l254.yx + c[3].zw;
  r1.zw = r0.xy * l255.wz + c[3].xy;
  r3 = SampleNoise(r1.zw);
  r4 = SampleNoise(r1.xy);
  r2.yz = r0.yx + l254.zz;
  r2.x = r0.x * l254.w + l253.y;
  r1.z = dot(r4.yxzw, c[6].yxzw);
  r1.y = dot(r4.yxwz, c[6].yxwz);
  r1.x = dot(r3.yxzw, c[5].yxzw);
  r0.x = c[0].x + l253.x;
  r0.yzw = r2.xyz * r2.xyz;
  {
    float z = r0.y + r0.z;
    float w = r0.w + r0.z;
    r0.z = z;
    r0.w = w;
  }
  r0.y = r1.x + r1.y;
  r1.w = r0.w * c[1].x;
  r1.y = sqrt(abs(r0.z));
  r0.z = r1.w * r0.w + c[1].y;
  r0.zw = r2.zy * r0.z;
  r0.yzw = r0.yzw + l255.xyy;
  r1.y = r1.y * (-c[1].z);
  {
    float y = r0.x + r1.y;
    float w = r0.y + r1.z;
    r1.y = y;
    r1.w = w;
  }
  r1.z = c[0].y;
  r2 = SampleVignette(r1.yz);
  r0 = SampleScene(r0.zw);
  r3.xyz = r0.yzw * c[4].x;
  r2 = saturate(r2 + c[0].w);
  r2 = r2 + l253.z;
  r2 = r2 * c[2].y + l253.x;
  r2.x = r2.x * c[4].x;
  r0.yzw = r3.xyz * r2.yzw;
  r1.x = saturate(r1.w + r1.x);
  r0.x = r0.x * r2.x;
  return r1.x * c[4].y + r0;
}
