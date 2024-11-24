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

            #pragma vertex VertDefault
            #pragma fragment Frag

            #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
            
            TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
            TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);
            
            float4 unity_FogColor;
            float4 unity_FogParams;

            float4 Frag(VaryingsDefault i) : SV_Target
            {
                float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);

                /* RECONSTRUCT WORLD SPACE POSITION AND DIRECTION FROM THE CURRENT PIXEL */
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.texcoord);
                float linearDepth = Linear01Depth(depth);

                // direction from camera towards this frag on screen
                /*
                      /- - -
                C -> | - - -
                      \- - -
                */
                float distanceFromCamera = (linearDepth * _ProjectionParams.z /* (camera's far plane) */) - _ProjectionParams.y /* (camera's near plane) */;

                // exponential fog
                float density = unity_FogParams.y; // in UnityShaderVariables.cginc : y = density / ln(2)
                half fogFactor = density * (distanceFromCamera);
                fogFactor = exp2(-fogFactor);
                fogFactor = saturate(fogFactor);

                // original. to implement later
                /*
                half4 sceneColorDark = sceneColor * pow(fogFac, clamp(_EnLoss,0.001,100));
                return lerp(unity_FogColor * half4(_FogTint.rgb,1), lerp(sceneColor, sceneColorDark, _MaxValue),  clamp(fogFac, 1 - _MaxValue ,1));
                */
                return lerp(unity_FogColor, color, fogFactor);
            }

            ENDHLSL
        }
    }
}