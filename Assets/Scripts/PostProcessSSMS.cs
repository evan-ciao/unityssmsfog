using System;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;

namespace Evan
{
    [Serializable]
    [PostProcess(typeof(PostProcessSSMSRenderer), PostProcessEvent.AfterStack, "Evan/Post Process SSMS")]
    public sealed class PostProcessSSMS : PostProcessEffectSettings
    {
        [Header("Blurring")]
        
        [Tooltip("Blend factor of the effect.")]
        [Range(0, 1)]
        public FloatParameter intensity = new FloatParameter { value = 1.0f };

        [Tooltip("Weight of the blur texture in the combiner pass.")]
        [Range(0, 1)]
        public FloatParameter blurWeight = new FloatParameter { value = 0.8f };

        [Tooltip("Blur tint.")]
        public ColorParameter blurTint = new ColorParameter { value = Color.white };

        [Tooltip("Blur effect multiplier.")]
        public FloatParameter radius = new FloatParameter { value = 5.0f };
        
        /*  -   -   -   */

        [Header("Effect blending")]

        [Tooltip("Determines the blending of the effects over distance.")]
        public TextureParameter fadeRamp = new TextureParameter { value = null };

        [Tooltip("To write")]
        [Range(0, 1)]
        public FloatParameter softKnee = new FloatParameter { value = 0.5f };
    }

    public sealed class PostProcessSSMSRenderer : PostProcessEffectRenderer<PostProcessSSMS>
    {
        public override void Render(PostProcessRenderContext context)
        {
            var sheet = context.propertySheets.Get(Shader.Find("Hidden/Evan/SSMS Post Process"));

            //sheet.properties.SetTexture("_BaseTex", settings.debugTexture);

            /* SET SHADER CONSTANTS */
            sheet.properties.SetFloat("_BlurWeight", settings.blurWeight);

            int prefilterNameID = Shader.PropertyToID("_SSMSPrefilterTex");
            context.command.GetTemporaryRT(prefilterNameID, Screen.width, Screen.height, 0);
            context.command.BlitFullscreenTriangle(context.source, prefilterNameID, sheet, 0);    // prefilter pass

            int levelOneID = Shader.PropertyToID("_SSMSLevelOneTex");
            int levelTwoID = Shader.PropertyToID("_SSMSLevelTwoTex");
            int levelThreeID = Shader.PropertyToID("_SSMSLevelThreeTex");
            int levelFourID = Shader.PropertyToID("_SSMSLevelFourTex");

            context.command.GetTemporaryRT(levelOneID, (int)(Screen.width / 2), (int)(Screen.height / 2), 0);
            context.command.GetTemporaryRT(levelTwoID, (int)(Screen.width / 4), (int)(Screen.height / 4), 0);
            context.command.GetTemporaryRT(levelThreeID, (int)(Screen.width / 8), (int)(Screen.height / 8), 0);
            context.command.GetTemporaryRT(levelFourID, (int)(Screen.width / 16), (int)(Screen.height / 16), 0);

            // iteratively downsample
        }
    }
}