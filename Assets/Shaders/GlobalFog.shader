Shader "Hidden/Evan/Global Fog Post Process"
{
    Subshader
    {
        ZTest Always Cull Off ZWrite Off Fog{ Mode Off }

        // the bible (´˘ -˘ 人)
        // https://docs.unity3d.com/6000.0/Documentation/Manual/SL-UnityShaderVariables.html

        // distance and height fog pass
        Pass
        {
            HLSLPROGRAM

            #include "GlobalFog.hlsl"

            #pragma vertex VertDefault
            #pragma fragment Frag

            float4 Frag(VaryingsDefault i) : SV_Target
            {
                return FullscreenFogEffect(i);
            }

            ENDHLSL
        }
    
        // only fog pass (used by PostProcessGlobalFog.cs to blit to fogTex)
        Pass
        {
            HLSLPROGRAM

            #include "GlobalFog.hlsl"

            #pragma vertex VertDefault
            #pragma fragment Frag

            float4 Frag(VaryingsDefault i) : SV_Target
            {
                return OnlyFogEffect(i);
            }

            ENDHLSL
        }
    }
}