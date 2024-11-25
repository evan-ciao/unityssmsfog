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
            float4x4 unity_CameraInvProjection;
            float4x4 unity_CameraToWorld;

            /* HEIGHT FOG VARIABlES SET FROM THE POSTPROCESSGLOBALFOGRENDERER */
            float3 fogPlaneNormal;
            float fogPlaneHeight;
            float heightFogDensity;
            float fogNormalDotCamera;
            float k;
            

            float4 Frag(VaryingsDefault i) : SV_Target
            {
                float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);

                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.texcoord);
                float linearDepth = Linear01Depth(depth);

                // direction from camera towards this frag on screen
                /*
                      /- - -
                C -> | - - -
                      \- - -
                */
                float distanceFromCamera = (linearDepth * _ProjectionParams.z /* (camera's far plane) */) - _ProjectionParams.y /* (camera's near plane) */;

                /* DISTANCE FOG */
                float density = unity_FogParams.y;  // in UnityShaderVariables.cginc : y = density / ln(2)
                half fogFactor = density * (distanceFromCamera);
                fogFactor = exp2(-fogFactor);
                
                /* HEIGHT FOG */
                // calculate world position
                float2 ndc = i.texcoord * 2 - 1;    // normalized device coordinates ([0 -> 1] to [-1 -> 1])
                float3 fragViewRay = mul(unity_CameraInvProjection, float4(ndc, 1.0, 1.0) * _ProjectionParams.z);  // ray passing through UVs and far plane
                float3 fragViewPosition = fragViewRay * linearDepth;  // multiplied by depth to retrieve the view-space position
                float3 fragWorldPosition = mul(unity_CameraToWorld, float4(fragViewPosition * float3(1.0,1.0,-1.0), 1.0)).xyz; // transform by the cameraToWorld matrix

                // good. now we can calculate half-space fog thanks to https://www.terathon.com/lengyel/Lengyel-UnifiedFog.pdf
                float3 cameraWorldPosition = _WorldSpaceCameraPos;

                float fogNormalDotFragWorld = fragWorldPosition.y - fogPlaneHeight; // evaluated foreach frag
                float fogNormalDotFragV = dot(fogPlaneNormal, cameraWorldPosition - fogNormalDotFragWorld);

                float heightFogFactor = -(heightFogDensity / 2) * distanceFromCamera * (k * (fogNormalDotFragWorld + fogNormalDotCamera) - ( pow(min( (1 - 2 * k) * fogNormalDotFragWorld , 0), 2) / ( abs(fogNormalDotFragV) + 0.00001 ) ));

                fogFactor -= heightFogFactor;
                fogFactor = saturate(fogFactor);

                // original. to implement later
                /*
                half4 sceneColorDark = sceneColor * pow(fogFac, clamp(_EnLoss,0.001,100));
                return lerp(unity_FogColor * half4(_FogTint.rgb,1), lerp(sceneColor, sceneColorDark, _MaxValue),  clamp(fogFac, 1 - _MaxValue ,1));
                */
                //return float4(fragWorldPosition, 1);

                //return float4(i.texcoord, linearDepth, 1);
                //return heightFogFactor;
                return lerp(unity_FogColor, color, fogFactor);
            }

            ENDHLSL
        }
    }
}