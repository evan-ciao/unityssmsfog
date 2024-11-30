#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"

/* GLOBAL VARIABLES AND DEFINITIONS */
TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
float4 _MainTex_TexelSize;

TEXTURE2D_SAMPLER2D(_FogTex, sampler_FogTex);
TEXTURE2D_SAMPLER2D(_BaseTex, sampler_BaseTex);

float _SampleScale;

float _Radius;
float _Blend;

float _BlurWeight;
float4 _BlurTint;

float3 _ResponseCurve;
float _BrightnessThreshold;

/* UTILITY FUNCTIONS */

float Brightness(float4 color)
{
    return max(max(color.r, color.g), color.b);
}

float4 Median(float4 a, float4 b, float4 c)
{
    return a + b + c - min(min(a, b), c) - max(max(a, b), c);
}

/* DOWNSAMPLING FUNCTIONS */

// 4x4 box blur
float4 DownsampleFilter(float2 uv)
{
    float4 offsets = _MainTex_TexelSize.xyxy * float4(-1, -1, 1, 1);

    float4 frag;
    frag = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offsets.xy);
    frag += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offsets.zy);
    frag += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offsets.xw);
    frag += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offsets.zw);

    return frag * (1.0 / 4);
}

// 4x4 box blur with anti flicker
float4 DownsampleAntiFlickerFilter(float2 uv)
{
    // box blur works by averaging the neighbour pixels of the current pixel being drawn
    // https://en.wikipedia.org/wiki/Box_blur

    float4 offsets = _MainTex_TexelSize.xyxy * float4(-1, -1, 1, 1);

    float4 frag1 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offsets.xy);
    float4 frag2 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offsets.zy);
    float4 frag3 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offsets.xw);
    float4 frag4 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offsets.zw);

    // karis's luma weighted average adjusts neighbours influence based on brightness
    float frag1weight = 1 / (Brightness(frag1) + 1);
    float frag2weight = 1 / (Brightness(frag2) + 1);
    float frag3weight = 1 / (Brightness(frag3) + 1);
    float frag4weight = 1 / (Brightness(frag4) + 1);
    float weightedSumReciprocal = 1 / (frag1weight + frag2weight + frag3weight + frag4weight);

    return (frag1 * frag1weight + frag2 * frag2weight + frag3 * frag3weight + frag4 * frag4weight) * weightedSumReciprocal;
}

/* UPSAMPLING FUNCTIONS */

float4 UpsampleFilter(float2 uv)
{
    // 9-tap bilinear upsampler
    // the upsampler "taps" 9 samples to compute each pixel in the upsampled image
    float4 offsets = _MainTex_TexelSize.xyxy * float4(1, 1, -1, 0) * _SampleScale;

    float4 frag;

    // the center pixel has a weight of 4
    // adjacent pixels have a weight of 2
    // digonal pixels have a weight of 1

    frag = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv - offsets.xy);
    frag += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv - offsets.wy) * 2;
    frag += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv - offsets.zy);

    frag += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offsets.zw) * 2;
    frag += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv) * 4;
    frag += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offsets.xw) * 2;

    frag += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offsets.zy);
    frag += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offsets.wy) * 2;
    frag += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offsets.xy);

    return frag * _BlurTint * (1.0 / 16);
}

/* FRAGMENT SHADERS */

float4 FragPrefilter(VaryingsDefault i)
{
    // brightness adjustments and such
    float3 offsets = _MainTex_TexelSize.xyx * float3(1, 1, 0);

    // adjacent pixels
    float4 frag0 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);
    float4 frag1 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord - offsets.xz);
    float4 frag2 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + offsets.xz);
    float4 frag3 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord - offsets.zy);
    float4 frag4 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + offsets.zy);

    float median = Median(Median(frag0, frag1, frag2), frag3, frag4);
    median = 1 - median;

    float brightness = Brightness(median);

    // threshold adjustments
    float responseQuantity = clamp(brightness - _ResponseCurve.x, 0, _ResponseCurve.y);
    responseQuantity = _ResponseCurve.z * pow(responseQuantity, 2);

    // apply brightness response curve
    median *= max(responseQuantity, brightness - _BrightnessThreshold) / max(brightness, 1e-5);

    return median;
}

float4 FragFirstDownsampler(VaryingsDefault i)
{
    return DownsampleAntiFlickerFilter(i.texcoord);    
}

float4 FragSecondDownsampler(VaryingsDefault i)
{
    return DownsampleFilter(i.texcoord);
}

float4 FragUpsampler(VaryingsDefault i)
{
    float4 blur = UpsampleFilter(i.texcoord);
    
    return (blur * (1 + _BlurWeight)) / (1 + (_BlurWeight * 0.735));
}

float4 FragCombiner(VaryingsDefault i)
{
    float4 base = SAMPLE_TEXTURE2D(_BaseTex, sampler_BaseTex, i.texcoord);
    float4 blur = UpsampleFilter(i.texcoord);

    float fog = SAMPLE_TEXTURE2D(_FogTex, sampler_FogTex, i.texcoord);

    return lerp(base, blur * (1 / _Radius), clamp(fog, 0, _Blend));
}