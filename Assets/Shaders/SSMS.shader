Shader "Hidden/Evan/SSMS Post Process"
{
    Subshader
    {
        ZTest Always Cull Off ZWrite Off
        
        /* 0 Prefilter with anti-flicker pass */
        Pass
        {
            HLSLPROGRAM

            #include "SSMS.hlsl"
            #pragma vertex VertDefault
            #pragma fragment Frag

            float4 Frag(VaryingsDefault i) : SV_Target
            {                
                return FragPrefilter(i);
            }

            ENDHLSL
        }
        
        /* 1 First level downsampler with anti-flicker pass */
        Pass
        {
            HLSLPROGRAM

            #include "SSMS.hlsl"
            #pragma vertex VertDefault
            #pragma fragment Frag

            float4 Frag(VaryingsDefault i) : SV_Target
            {                
                return FragFirstDownsampler(i);
            }

            ENDHLSL
        }

        /* 2 Second level downsampler pass */
        Pass
        {
            HLSLPROGRAM

            #include "SSMS.hlsl"
            #pragma vertex VertDefault
            #pragma fragment Frag

            float4 Frag(VaryingsDefault i) : SV_Target
            {                
                return FragSecondDownsampler(i);
            }

            ENDHLSL
        }
        
        /* 3 High quality upsampler pass */
        Pass
        {
            HLSLPROGRAM

            #include "SSMS.hlsl"
            #pragma vertex VertDefault
            #pragma fragment Frag

            float4 Frag(VaryingsDefault i) : SV_Target
            {                
                return FragUpsampler(i);
            }

            ENDHLSL
        }

        /* 4 High quality combiner */
        Pass
        {
            HLSLPROGRAM

            #include "SSMS.hlsl"
            #pragma vertex VertDefault
            #pragma fragment Frag

            float4 Frag(VaryingsDefault i) : SV_Target
            {                
                return FragCombiner(i);
            }

            ENDHLSL
        }
    }
}