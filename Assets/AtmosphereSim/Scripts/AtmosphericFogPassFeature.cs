using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class AtmosphericFogPassFeature : ScriptableRendererFeature
{
    class AtmosphericFogPass : ScriptableRenderPass
    {
        public Material material;
        public RTHandle colorRT;
        public bool enableLightShaft;
        public bool displayExtinction;
        public bool displayInscattering;
        public AtmosphericFogPass(Settings settings)
        {
            material = settings.material;
            renderPassEvent = settings.renderPassEvent;
            enableLightShaft = settings.enableLightShaft;
            displayExtinction = settings.displayExtinction;
            displayInscattering = settings.displayInscattering;
        }
        
        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in a performant manner.
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            RenderTextureDescriptor colorCopyDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            RenderingUtils.ReAllocateIfNeeded(ref colorRT, colorCopyDescriptor, name: "AtmosphericFogPass");

            CommandBuffer cmd = CommandBufferPool.Get("AtmosphericFogPass");
            RTHandle sourceRT = null;
            sourceRT = renderingData.cameraData.renderer.cameraColorTargetHandle;
            // CoreUtils.DrawFullScreen(cmd,material);
            if (enableLightShaft)
            {
                material.EnableKeyword("_LIGHTSHAFT_ON");
            }
            else
            {
                material.DisableKeyword("_LIGHTSHAFT_ON");
            }
            if (displayExtinction)
            {
                material.EnableKeyword("_EXTINCTION_ON");
            }
            else
            {
                material.DisableKeyword("_EXTINCTION_ON");
            }
            if (displayInscattering)
            {
                material.EnableKeyword("_INSCATTERING_ON");
            }
            else
            {
                material.DisableKeyword("_INSCATTERING_ON");
            }
            cmd.Blit(sourceRT.nameID, renderingData.cameraData.renderer.cameraColorTargetHandle.nameID, material);
            
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public void Dispose()
        {
            colorRT?.Release();
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    [System.Serializable]
    public class Settings
    {
        public Material material;
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        public bool enableLightShaft = true;
        public bool displayExtinction = false;
        public bool displayInscattering = false;
    }

    public Settings settings;
    AtmosphericFogPass m_AtmosphericFogPass;

    /// <inheritdoc/>
    public override void Create()
    {
        m_AtmosphericFogPass = new AtmosphericFogPass(settings);
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (settings.material == null)
        {
            Debug.LogWarningFormat("Missing LightShafts Material. {0} pass will not execute. Check for missing reference in the assigned renderer.", GetType().Name);
            return;
        }
        renderer.EnqueuePass(m_AtmosphericFogPass);
    }

    protected override void Dispose(bool disposing)
    {
        m_AtmosphericFogPass.Dispose();
    }
}


