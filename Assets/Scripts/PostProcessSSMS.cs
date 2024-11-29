using System;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;

namespace Evan
{
    [Serializable]
    [PostProcess(typeof(PostProcessSSMSRenderer), PostProcessEvent.AfterStack, "Evan/Post Process SSMS")]
    public sealed class PostProcessSSMS : PostProcessEffectSettings
    {
    }

    public sealed class PostProcessSSMSRenderer : PostProcessEffectRenderer<PostProcessGlobalFog>
    {
        public override void Render(PostProcessRenderContext context)
        {
            var sheet = context.propertySheets.Get(Shader.Find("Hidden/Evan/SSMS Post Process"));

            context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);
        }
    }
}