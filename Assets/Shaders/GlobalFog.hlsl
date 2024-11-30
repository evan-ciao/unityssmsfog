#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"

TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);

float4 unity_FogColor;
float4 unity_FogParams;
float4x4 unity_CameraInvProjection;
float4x4 unity_CameraToWorld;

/* HEIGHT FOG VARIABLES SET FROM THE POSTPROCESSGLOBALFOGRENDERER */
float3 fogPlaneNormal;
float fogPlaneHeight;
float heightFogDensity;
float fogNormalDotCamera;
float k;

/* PARAMETERS SET FROM THE POSTPROCESSGLOBALFOGRENDERER */
float4 globalFogTint;
float energyLoss;
float globalFogMaxDensity;

// used in the first pass
float4 FullscreenFogEffect(VaryingsDefault i)
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

    float heightFogFactor = -(heightFogDensity * distanceFromCamera) * (k * (fogNormalDotFragWorld + fogNormalDotCamera) - ( pow(min( (1 - 2 * k) * fogNormalDotFragWorld , 0), 2) / ( abs(fogNormalDotFragV + 0.00001) ) ));

    fogFactor -= heightFogFactor;
    fogFactor = saturate(fogFactor);
    
    fogFactor = 1 - fogFactor;

    half4 colorDark = color * pow(fogFactor, clamp(energyLoss, 0.001, 100));
    return lerp(lerp(color, colorDark, globalFogMaxDensity), unity_FogColor * half4(globalFogTint.rgb, 1), clamp(fogFactor, 1 - globalFogMaxDensity, 1));
}

// used in the second pass (assign global fogTex)
float4 OnlyFogEffect(VaryingsDefault i)
{
    float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);
    float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.texcoord);
    float linearDepth = Linear01Depth(depth);
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

    float3 cameraWorldPosition = _WorldSpaceCameraPos;
    float fogNormalDotFragWorld = fragWorldPosition.y - fogPlaneHeight; // evaluated foreach frag
    float fogNormalDotFragV = dot(fogPlaneNormal, cameraWorldPosition - fogNormalDotFragWorld);
    float heightFogFactor = -(heightFogDensity * distanceFromCamera) * (k * (fogNormalDotFragWorld + fogNormalDotCamera) - ( pow(min( (1 - 2 * k) * fogNormalDotFragWorld , 0), 2) / ( abs(fogNormalDotFragV + 0.00001) ) ));

    fogFactor -= heightFogFactor;
    fogFactor = saturate(fogFactor);

    return 1 - fogFactor;
}