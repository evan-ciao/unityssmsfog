using System;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;

namespace Evan
{
    [Serializable]
    [PostProcess(typeof(PostProcessGlobalFogRenderer), PostProcessEvent.BeforeStack, "Evan/Post Process Global Fog")]
    public sealed class PostProcessGlobalFog : PostProcessEffectSettings
    {

    }

    public sealed class PostProcessGlobalFogRenderer : PostProcessEffectRenderer<PostProcessGlobalFog>
    {
        public override void Render(PostProcessRenderContext context)
        {
            var sheet = context.propertySheets.Get(Shader.Find("Hidden/Evan/Global Fog Post Process"));

            context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);
        }
    }
}