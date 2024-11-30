using System;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;
using UnityEngine.UIElements;

namespace Evan
{
    [Serializable]
    [PostProcess(typeof(PostProcessSSMSRenderer), PostProcessEvent.AfterStack, "Evan/Post Process SSMS")]
    public sealed class PostProcessSSMS : PostProcessEffectSettings
    {
        [Header("Blurring")]

        [Tooltip("Blur effect multiplier.")]
        public FloatParameter radius = new FloatParameter { value = 5.0f };

        [Tooltip("Weight of the blur texture in the combiner pass.")]
        [Range(0, 1)]
        public FloatParameter blurWeight = new FloatParameter { value = 0.8f };

        [Tooltip("Blur tint.")]
        public ColorParameter blurTint = new ColorParameter { value = Color.white };
        
        /*  -   -   -   */

        [Header("Effect blending")]

        [Tooltip("Blend factor of the effect.")]
        [Range(0, 1)]
        public FloatParameter blend = new FloatParameter { value = 1.0f };

        [Tooltip("To write")]
        [Range(0, 1)]
        public FloatParameter softKnee = new FloatParameter { value = 0.5f };

        public FloatParameter brightnessThreshold = new FloatParameter { value = 0.5f };
    }

    public sealed class PostProcessSSMSRenderer : PostProcessEffectRenderer<PostProcessSSMS>
    {
        public override void Render(PostProcessRenderContext context)
        {
            var sheet = context.propertySheets.Get(Shader.Find("Hidden/Evan/SSMS Post Process"));

            /* SET SHADER CONSTANTS */
            sheet.properties.SetFloat("_SampleScale", 0.2f);    // to edit
            sheet.properties.SetFloat("_Blend", settings.blend);
            sheet.properties.SetFloat("_Radius", settings.radius);
            sheet.properties.SetFloat("_BlurWeight", settings.blurWeight);
            sheet.properties.SetColor("_BlurTint", settings.blurTint);
            sheet.properties.SetFloat("_BrightnessThreshold", settings.brightnessThreshold);

            // calculate response curve
            float knee = settings.brightnessThreshold * settings.softKnee + 1e-5f;
            Vector3 curve = new Vector3(settings.brightnessThreshold - knee, knee * 2, 0.25f / knee);
            sheet.properties.SetVector("_ResponseCurve", curve);

            /* PASSES */
            RenderTexture prefiltered = context.GetScreenSpaceTemporaryRT();

            context.command.BlitFullscreenTriangle(context.source, prefiltered, sheet, 0);

            int iterations = 2;
            RenderTexture[] blurBuffer1 = new RenderTexture[iterations];
            RenderTexture[] blurBuffer2 = new RenderTexture[iterations];

            var lastWorkTex = prefiltered;

            // downsample loop
            for (int i = 0; i < iterations; i++)
            {
                blurBuffer1[i] = context.GetScreenSpaceTemporaryRT(widthOverride: lastWorkTex.width / 2, heightOverride: lastWorkTex.height / 2);

                context.command.BlitFullscreenTriangle(lastWorkTex, blurBuffer1[i], sheet, (i == 0) ? 1 : 2); // downsample pass

                lastWorkTex = blurBuffer1[i];
            }

            // upsample loop
            for (int i = iterations - 2; i >= 0; i--)
            {
                var baseTex = blurBuffer1[i];
                context.command.SetGlobalTexture("_BaseTex", baseTex);

                blurBuffer2[i] = context.GetScreenSpaceTemporaryRT(widthOverride: baseTex.width / 2, heightOverride: baseTex.height / 2);

                context.command.BlitFullscreenTriangle(lastWorkTex, blurBuffer2[i], sheet, 3);
                lastWorkTex = blurBuffer2[i];
            }

            context.command.SetGlobalTexture("_BaseTex", context.source);
            
            // combine pass and output
            context.command.BlitFullscreenTriangle(lastWorkTex, context.destination, sheet, 4);

            // clean up
            if(prefiltered != null)
                RenderTexture.ReleaseTemporary(prefiltered);
            foreach (var blur in blurBuffer1)
                if(blur != null)
                    RenderTexture.ReleaseTemporary(blur);
            foreach (var blur in blurBuffer2)
                if(blur != null)
                    RenderTexture.ReleaseTemporary(blur);
        }
    }
}