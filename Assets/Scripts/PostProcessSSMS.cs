using System;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;

namespace Evan
{
    [Serializable]
    [PostProcess(typeof(PostProcessSSMSRenderer), PostProcessEvent.AfterStack, "Evan/Post Process SSMS")]
    public sealed class PostProcessSSMS : PostProcessEffectSettings
    {
        public TextureParameter debugTexture = new TextureParameter { value = null };
        
        [Header("Blurring")]
        [Range(0, 1)]
        public FloatParameter blurWeight = new FloatParameter { value = 0.8f };
    }

    public sealed class PostProcessSSMSRenderer : PostProcessEffectRenderer<PostProcessSSMS>
    {
        public override void Render(PostProcessRenderContext context)
        {
            var sheet = context.propertySheets.Get(Shader.Find("Hidden/Evan/SSMS Post Process"));

            if(settings.debugTexture.value == null)
                return;

            sheet.properties.SetTexture("_BaseTex", settings.debugTexture);

            /* SET CONSTANTS */
            sheet.properties.SetFloat("_BlurWeight", settings.blurWeight);

            context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);
        }
    }
}