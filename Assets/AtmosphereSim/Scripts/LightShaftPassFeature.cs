using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class LightShaftPassFeature : ScriptableRendererFeature
{
    class LightShaftPass : ScriptableRenderPass
    {
        public Material material;
        private RenderTargetHandle lightShaftLut;

        public LightShaftPass(Material material)
        {
            renderPassEvent = RenderPassEvent.BeforeRenderingPrePasses;
            this.material = material;
            lightShaftLut.Init("_LightShaft");
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
            if (!renderingData.shadowData.supportsMainLightShadows) return;
            CommandBuffer cmd = CommandBufferPool.Get("LightShafts");

            int width = renderingData.cameraData.cameraTargetDescriptor.width;
            int height = renderingData.cameraData.cameraTargetDescriptor.height;

            cmd.GetTemporaryRT(lightShaftLut.id, width, height, 0, FilterMode.Bilinear, RenderTextureFormat.R8);
            cmd.Blit(lightShaftLut.id, lightShaftLut.id, material, 0);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(lightShaftLut.id);
        }
    }

    [System.Serializable]
    public class Settings
    {
        public Material lightShaftMat = null;
    }

    public Settings settings = new Settings();
    LightShaftPass lightShaftPass;

    /// <inheritdoc/>
    public override void Create()
    {
        lightShaftPass = new LightShaftPass(settings.lightShaftMat);

        // // Configures where the render pass should be injected.
        // lightShaftPass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (settings.lightShaftMat == null)
        {
            Debug.LogWarningFormat("Missing LightShafts Material. {0} pass will not execute. Check for missing reference in the assigned renderer.", GetType().Name);
            return;
        }

        renderer.EnqueuePass(lightShaftPass);
    }
}