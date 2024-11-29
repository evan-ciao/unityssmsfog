#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"

/* GLOBAL VARIABLES AND DEFINITIONS */
TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
float4 _MainTex_TexelSize;

float _SampleScale;

/* UTILITY FUNCTIONS */

half Brightness(half3 color)
{
    return max(max(color.r, color.g), color.b);
}

half3 Median(half3 a, half3 b, half3 c)
{
    return a + b + c - min(min(a, b), c) - max(max(a, b), c);
}


#define USE_RGBM defined(SHADER_API_MOBILE) // for mobile support
half4 EncodeHDR(float3 rgb)
{
    #if USE_RGBM
        rgb *= 1.0 / 8;
        float m = max(max(rgb.r, rgb.g), max(rgb.b, 1e-6));
        m = ceil(m * 255) / 255;
        return half4(rgb / m, m);
    #else
        return half4(rgb, 0);
    #endif
}

float3 DecodeHDR(half4 rgba)
{
    #if USE_RGBM
        return rgba.rgb * rgba.a * 8;
    #else
        return rgba.rgb;
    #endif
}

/* DOWNSAMPLING FUNCTIONS */

// 4x4 box blur
half3 DownsampleAntiFlickerFilter(float2 uv)
{
    // box blur works by averaging the neighbour pixels of the current pixel being drawn
    // https://en.wikipedia.org/wiki/Box_blur

    float4 offsets = _MainTex_TexelSize.xyxy * float4(-1, -1, 1, 1);

    half3 frag1 = DecodeHDR(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offsets.xy));
    half3 frag2 = DecodeHDR(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offsets.zy));
    half3 frag3 = DecodeHDR(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offsets.xw));
    half3 frag4 = DecodeHDR(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offsets.zw));

    // karis's luma weighted average adjusts neighbours influence based on brightness
    half frag1weight = 1 / (Brightness(frag1) + 1);
    half frag2weight = 1 / (Brightness(frag2) + 1);
    half frag3weight = 1 / (Brightness(frag3) + 1);
    half frag4weight = 1 / (Brightness(frag4) + 1);
    half weightedSumReciprocal = 1 / (frag1weight + frag2weight + frag3weight + frag4weight);

    return (frag1 * frag1weight + frag2 * frag2weight + frag3 * frag3weight + frag4 * frag4weight) * weightedSumReciprocal;
}

/* UPSAMPLING FUNCTIONS */

half3 UpsampleFilter(float2 uv)
{
    // 9-tap bilinear upsampler
    // the upsampler "taps" 9 samples to compute each pixel in the upsampled image
    float4 offsets = _MainTex_TexelSize.xyxy * float4(1, 1, -1, 0) * _SampleScale;

    half3 frag;

    // the center pixel has a weight of 4
    // adjacent pixels have a weight of 2
    // digonal pixels have a weight of 1

    frag = DecodeHDR(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv - offsets.xy));
    frag += DecodeHDR(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv - offsets.wy)) * 2;
    frag += DecodeHDR(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv - offsets.zy));

    frag += DecodeHDR(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offsets.zw)) * 2;
    frag += DecodeHDR(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv)) * 4;
    frag += DecodeHDR(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offsets.xw)) * 2;

    frag += DecodeHDR(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offsets.zy));
    frag += DecodeHDR(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offsets.wy)) * 2;
    frag += DecodeHDR(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + offsets.xy));

    return frag * (1.0 / 16);
}

/* FRAGMENT SHADERS */