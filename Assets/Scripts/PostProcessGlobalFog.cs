using System;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;

namespace Evan
{
    [Serializable]
    [PostProcess(typeof(PostProcessGlobalFogRenderer), PostProcessEvent.BeforeStack, "Evan/Post Process Global Fog")]
    public sealed class PostProcessGlobalFog : PostProcessEffectSettings
    {
        [Header("Global fog settings")]
        public ColorParameter globalFogColor = new ColorParameter { value = new Color(0.4f, 0.4f, 0.4f) };
        public FloatParameter globalFogDensity = new FloatParameter { value = 0.05f };

        [Header("Height fog settings")]
        [Range(0.001f, 10f)]
        public FloatParameter heightFogHeight = new FloatParameter { value = 0.3f };
        [Range(0, 2f)]
        public FloatParameter heightFogDensity = new FloatParameter { value = 0.3f };
    }

    public sealed class PostProcessGlobalFogRenderer : PostProcessEffectRenderer<PostProcessGlobalFog>
    {
        Vector3 fogPlaneNormal = Vector3.up;

        public override void Render(PostProcessRenderContext context)
        {
            var sheet = context.propertySheets.Get(Shader.Find("Hidden/Evan/Global Fog Post Process"));

            /* SET GLOBAL FOG SETTINGS */
            RenderSettings.fogMode = FogMode.ExponentialSquared;
            RenderSettings.fogColor = settings.globalFogColor;
            RenderSettings.fogDensity = settings.globalFogDensity;

            /* CALCULATE CONSTANTS FOR HEIGHT FOG */
            float fogNormalDotCamera = Vector3.Dot(Camera.current.transform.position, fogPlaneNormal);
            float k = fogNormalDotCamera <= 0 ? 1 : 0;  // ... are we in the height fog volume or not?
            Debug.Log(fogNormalDotCamera);
            sheet.properties.SetVector("fogPlaneNormal", fogPlaneNormal);
            sheet.properties.SetFloat("fogPlaneHeight", settings.heightFogHeight);
            sheet.properties.SetFloat("heightFogDensity", settings.heightFogDensity);
            sheet.properties.SetFloat("fogNormalDotCamera", fogNormalDotCamera);
            sheet.properties.SetFloat("k", k);

            context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);
        }
    }
}