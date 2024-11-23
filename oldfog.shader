Shader "PostProcessFog"
{
    Properties
    {
        //_MainTex("Base (RGB)", 2D) = "black" {}
        _CameraDepthTexture ("Depth", 2D) = "blue" {}

    }
  
    HLSLINCLUDE

        //#include "Assets/PostProcessing/Shaders/StdLib.hlsl"
        #include "UnityCG.cginc"

        uniform sampler2D _MainTex;
        uniform sampler2D_float _CameraDepthTexture;

        uniform float4 _HeightParams;
        uniform float4 _DistanceParams;

        int4 _SceneFogMode; // x = fog mode, y = use radial flag
        float4 _SceneFogParams;

        float _EnLoss;
        float _MaxValue;
        float4 _FogTint;


        #ifndef UNITY_APPLY_FOG
            half4 unity_FogColor;
            half4 unity_FogDensity;
        #endif

        uniform float4 _MainTex_TexelSize;

        // for fast world space reconstruction
        uniform float4x4 _FrustumCornersWS;
        uniform float4 _CameraWS;

        float LinearEyeDepth135( float z )
        {
            return LinearEyeDepth( z );
        }
        // Vertex manipulation
        float2 TransformTriangleVertexToUV(float2 vertex)
        {
            float2 uv = (vertex + 1.0) * 0.5;
            return uv;
        }
        //-----------------------------------------------------------------------------
        //Default vertex shaders

        struct AttributesDefault
        {
            float3 vertex : POSITION;
            half2 texcoord : TEXCOORD0;
        };

        struct VaryingsDefault
        {
            float4 pos : SV_POSITION;
            float2 uv : TEXCOORD0;
            //float2 uvStereo : TEXCOORD1;
            float2 uv_depth : TEXCOORD1;
            float4 interpolatedRay : TEXCOORD2;
        };

        VaryingsDefault VertDefault(AttributesDefault v  )
        {
            VaryingsDefault o;
            v.vertex.z = 0.1;
            o.pos = float4(v.vertex.xy, 0.0, 1.0);
            o.uv = TransformTriangleVertexToUV(v.vertex.xy);
            o.uv_depth = v.texcoord.xy;

            #if UNITY_UV_STARTS_AT_TOP
                o.uv = o.uv * float2(1.0, -1.0) + float2(0.0, 1.0);
            #endif
          
            //o.uvStereo = TransformStereoScreenSpaceTex(o.uv, 1.0);

            #if UNITY_UV_STARTS_AT_TOP
                if (_MainTex_TexelSize.y < 0)
                    o.uv.y = 1 - o.uv.y;
            #endif

            int frustumIndex = v.texcoord.x + (2 * o.uv.y);
            o.interpolatedRay = _FrustumCornersWS[frustumIndex];
            o.interpolatedRay.w = frustumIndex;

            return o;
        }
      
        // Applies one of standard fog formulas, given fog coordinate (i.e. distance)
        half ComputeFogFactor(float coord)    {

            float fogFac = 0.0;
            if (_SceneFogMode.x == 1) // linear
            {
                // factor = (end-z)/(end-start) = z * (-1/(end-start)) + (end/(end-start))
                fogFac = coord * _SceneFogParams.z + _SceneFogParams.w;
            }
            if (_SceneFogMode.x == 2) // exp
            {
                // factor = exp(-density*z)
                fogFac = _SceneFogParams.y * coord; fogFac = exp2(-fogFac);
            }
            if (_SceneFogMode.x == 3) // exp2
            {
                // factor = exp(-(density*z)^2)
                fogFac = _SceneFogParams.x * coord; fogFac = exp2(-fogFac*fogFac);
            }
            return saturate(fogFac);
        }

        // Distance-based fog
        float ComputeDistance(float3 camDir, float zdepth)
        {

            float dist;
            if (_SceneFogMode.y == 1)
                dist = length(camDir);
            else
                dist = zdepth * _ProjectionParams.z;
            // Built-in fog starts at near plane, so match that by
            // subtracting the near value. Not a perfect approximation
            // if near plane is very large, but good enough.
            dist -= _ProjectionParams.y;
            return dist;
        }

        // Linear half-space fog, from https://www.terathon.com/lengyel/Lengyel-UnifiedFog.pdf
        float ComputeHalfSpace(float3 wsDir)
        {

            float3 wpos = _CameraWS + wsDir;
            float FH = _HeightParams.x;
            float3 C = _CameraWS;
            float3 V = wsDir;
            float3 P = wpos;
            float3 aV = _HeightParams.w * V;
            float FdotC = _HeightParams.y;
            float k = _HeightParams.z;
            float FdotP = P.y - FH;
            float FdotV = wsDir.y;
            float c1 = k * (FdotP + FdotC);
            float c2 = (1 - 2 * k) * FdotP;
            float g = min(c2, 0.0);
            g = -length(aV) * (c1 - g * g / abs(FdotV + 1.0e-5f));
            return g;

        }

        half4 ComputeFog( VaryingsDefault i, bool distance, bool height) : SV_Target
        {
            half4 sceneColor = tex2D(_MainTex, UnityStereoTransformScreenSpaceTex(i.uv));

            // Reconstruct world space position & direction
            // towards this screen pixel.
            float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, UnityStereoTransformScreenSpaceTex(i.uv ));

            float dpth = Linear01Depth(rawDepth);
            float4 wsDir = dpth * i.interpolatedRay;
            float4 wsPos = _CameraWS + wsDir;

            // Compute fog distance
            float g = _DistanceParams.x;
            if (distance)
                g += ComputeDistance(wsDir, dpth);
            if (height)
                g += ComputeHalfSpace(wsDir);

            // Compute fog amount
            half fogFac = ComputeFogFactor(max(0.0,g));
            // Do not fog skybox
            if (dpth == _DistanceParams.y)
                fogFac = 1.0;
            //return fogFac; // for debugging

            // Lerp between fog color & original scene color
            // by fog amount
            half4 sceneColorDark = sceneColor * pow(fogFac, clamp(_EnLoss,0.001,100));
            return lerp(unity_FogColor * half4(_FogTint.rgb,1), lerp(sceneColor, sceneColorDark, _MaxValue),  clamp(fogFac, 1 - _MaxValue ,1));
        }

        half4 ComputeFogB( VaryingsDefault i, bool distance, bool height) : SV_Target
        {
            // Reconstruct world space position & direction
            // towards this screen pixel.
            float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, UnityStereoTransformScreenSpaceTex(i.uv ));
          
            float dpth = Linear01Depth(rawDepth);
            float4 wsDir = dpth * i.interpolatedRay;
            float4 wsPos = _CameraWS + wsDir;

            // Compute fog distance
            float g = _DistanceParams.x;
            if (distance)
                g += ComputeDistance(wsDir, dpth);
            if (height)
                g += ComputeHalfSpace(wsDir);

            // Compute fog amount
            half fogFac = ComputeFogFactor(max(0.0,g));
            // Do not fog skybox
            if (dpth == _DistanceParams.y)
                fogFac = 1.0;
            //return fogFac; // for debugging

            // Lerp between fog color & original scene color
            // by fog amount
            unity_FogColor = (unity_FogColor.r + unity_FogColor.y + unity_FogColor.z) / 3;
            unity_FogColor = unity_FogColor * (1 / unity_FogColor);
            return unity_FogColor * (1 - fogFac);
        }

    ENDHLSL

    SubShader
    {
        ZTest Always Cull Off ZWrite Off Fog{ Mode Off }

        // 0: distance + height
        Pass
        {
            HLSLPROGRAM
                #pragma vertex VertDefault
                #pragma fragment frag
                half4 frag(VaryingsDefault i) : SV_Target{ return ComputeFog(i, true, true); }
            ENDHLSL
        }
      
        // 1: distance
        Pass
        {
            HLSLPROGRAM
                #pragma vertex VertDefault
                #pragma fragment frag
                half4 frag(VaryingsDefault i) : SV_Target{ return ComputeFog(i, true, false); }
            ENDHLSL
        }
      
        // 2: height
        Pass
        {
            HLSLPROGRAM
                #pragma vertex VertDefault
                #pragma fragment frag
                half4 frag(VaryingsDefault i) : SV_Target{ return ComputeFog(i, false, true); }
            ENDHLSL
        }
           
        // Only outputs fog color
        // 3: distance + height
        Pass
        {
            HLSLPROGRAM
                #pragma vertex VertDefault
                #pragma fragment frag
                half4 frag(VaryingsDefault i) : SV_Target{ return ComputeFogB(i, true, true); }
            ENDHLSL
        }

        // 4: distance
        Pass
        {
            HLSLPROGRAM
                #pragma vertex VertDefault
                #pragma fragment frag
            half4 frag(VaryingsDefault i) : SV_Target{ return ComputeFogB(i, true, false); }
            ENDHLSL
        }

        // 5: height
        Pass
        {
            HLSLPROGRAM
                #pragma vertex VertDefault
                #pragma fragment frag
                half4 frag(VaryingsDefault i) : SV_Target{ return ComputeFogB(i, false, true); }
            ENDHLSL
        }

     } // End SubShader

} // End Shader