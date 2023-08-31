using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class VolumnCloudPassFeature : ScriptableRendererFeature
{
    class VolumnCloudPass : ScriptableRenderPass
    {
        public Material cloudMat;
        public Texture2D blueNoiseTex;
        public Color brightColor;
        public Color middleColor;
        public Color darkColor;
        public bool showCloudLayer;

        public RenderTargetIdentifier cameraColorTex;

        //纹理大小
        public int width;
        public int height;

        public VolumnCloudPass(Settings setting)
        {
            renderPassEvent = setting.renderPassEvent;
            cloudMat = setting.cloudMat;
            blueNoiseTex = setting.blueNoiseTex;
            brightColor = setting.brightColor;
            middleColor = setting.middleColor;
            darkColor = setting.darkColor;
            showCloudLayer = setting.showCloudLayer;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            cameraColorTex = renderingData.cameraData.renderer.cameraColorTargetHandle.nameID;
            width = renderingData.cameraData.cameraTargetDescriptor.width;
            height = renderingData.cameraData.cameraTargetDescriptor.height;
            CommandBuffer cmd = CommandBufferPool.Get("VolumnCloudPass");

            cloudMat.SetTexture("_BlueNoiseTex", blueNoiseTex);
            cloudMat.SetVector("_BlueNoiseTexUV", new Vector4((float) width / (float) blueNoiseTex.width, (float) height / (float) blueNoiseTex.height, 0, 0));

            if (showCloudLayer)
            {
                cloudMat.SetColor("_ColorBright", Color.red);
                cloudMat.SetColor("_ColorMiddle", Color.green);
                cloudMat.SetColor("_ColorDark", Color.blue);
            }
            else
            {
                cloudMat.SetColor("_ColorBright", brightColor);
                cloudMat.SetColor("_ColorMiddle", middleColor);
                cloudMat.SetColor("_ColorDark", darkColor);
            }

            //创建临时渲染纹理
            RenderTextureDescriptor tempDescriptor = new RenderTextureDescriptor(width, height, RenderTextureFormat.ARGB32);
            tempDescriptor.depthBufferBits = 0;
            int tempTextureID = Shader.PropertyToID("_CloudTex");
            cmd.GetTemporaryRT(tempTextureID, tempDescriptor);

            cmd.Blit(cameraColorTex, tempTextureID, cloudMat, 0);
            cmd.Blit(tempTextureID, cameraColorTex, cloudMat, 1);

            context.ExecuteCommandBuffer(cmd);

            cmd.ReleaseTemporaryRT(tempTextureID);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    [System.Serializable]
    public class Settings
    {
        public Material cloudMat;
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingSkybox;
        public Texture2D blueNoiseTex;
        public Color brightColor = Color.white;
        public Color middleColor = new Color(0.5f, 0.5f, 0.5f, 1f);
        public Color darkColor = new Color(0.2f, 0.2f, 0.2f, 1f);
        public bool showCloudLayer;
    }

    public Settings setting = new Settings();
    VolumnCloudPass m_VolumnCloudPass;

    /// <inheritdoc/>
    public override void Create()
    {
        m_VolumnCloudPass = new VolumnCloudPass(setting);
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (setting.cloudMat == null)
        {
            Debug.LogWarningFormat("Missing LightShafts Material. {0} pass will not execute. Check for missing reference in the assigned renderer.", GetType().Name);
            return;
        }

        renderer.EnqueuePass(m_VolumnCloudPass);
    }
}