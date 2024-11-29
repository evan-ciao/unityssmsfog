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
                half3 downsample = DownsampleAntiFlickerFilter(i.texcoord);
                return float4(downsample.x, downsample.y, downsample.z, 1);
            }

            ENDHLSL
        }
        
        /* 1 First level downsampler with anti-flicker pass */
        Pass
        {

        }

        /* 2 Second level downsampler pass */
        Pass
        {

        }
        
        /* 3 High quality upsampler pass */
        Pass
        {

        }

        /* 4 High quality combiner */
        Pass
        {

        }
    }
}