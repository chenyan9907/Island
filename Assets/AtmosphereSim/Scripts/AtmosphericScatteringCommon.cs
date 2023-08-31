using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace AtmosphericScatteringCommon
{
    public static class Keys
    {
        public static readonly int k_AtmosphereDensityToTopLUT = Shader.PropertyToID("_AtmosphereDensityToTopLUT");
        public static readonly int k_RWIntegrateAtmosphereDensityToTopLUT = Shader.PropertyToID("_RWIntegrateAtmosphereDensityToTopLUT");
        public static readonly int k_RWSunParamsLUT = Shader.PropertyToID("_RWSunParamsLUT");
        public static readonly int k_RandomVectorLUT = Shader.PropertyToID("_RandomVectorLUT");
        public static readonly int k_RWAmbientLightLUT = Shader.PropertyToID("_RWAmbientLightLUT");
        public static readonly int k_DitheringTex = Shader.PropertyToID("_DitheringTex");

        public static readonly int k_AtmosphereHeight = Shader.PropertyToID("_AtmosphereHeight");
        public static readonly int k_PlanetRadius = Shader.PropertyToID("_PlanetRadius");
        public static readonly int k_CurrentSceneHeight = Shader.PropertyToID("_CurrentSceneHeight");
        public static readonly int k_DensityScalarHeight = Shader.PropertyToID("_DensityScalarHeight");
        public static readonly int k_RayleighSct = Shader.PropertyToID("_RayleighSct");
        public static readonly int k_RayleighExt = Shader.PropertyToID("_RayleighExt");
        public static readonly int k_MieSct = Shader.PropertyToID("_MieSct");
        public static readonly int k_MieExt = Shader.PropertyToID("_MieExt");
        public static readonly int k_SunMieG = Shader.PropertyToID("_SunMieG");
        public static readonly int k_MieG = Shader.PropertyToID("_MieG");
        public static readonly int k_DistanceScale = Shader.PropertyToID("_DistanceScale");
        public static readonly int k_IncomingLight = Shader.PropertyToID("_IncomingLight");
        public static readonly int k_SunRenderIntensity = Shader.PropertyToID("_SunRenderIntensity");
        public static readonly int k_SunRenderColor = Shader.PropertyToID("_SunRenderColor");
        public static readonly int k_FrustumCorners = Shader.PropertyToID("_FrustumCorners");
        public static readonly int k_SunLightDir = Shader.PropertyToID("_SunLightDir");
    }

    public static class Utility
    {
        public static void CreateLUT(ref RenderTexture targetLut, Vector2Int size, RenderTextureFormat format)
        {
            // if (targetLut == null || (targetLut.width != size.x && targetLut.height != size.y))
            // {
                if (targetLut != null)
                    targetLut.Release();
                RenderTexture rt = new RenderTexture(size.x, size.y, 0, format, RenderTextureReadWrite.Linear);
                rt.useMipMap = false;
                rt.filterMode = FilterMode.Bilinear;
                rt.enableRandomWrite = true;
                rt.Create();
                targetLut = rt;
            // }
        }

        public static void Dispatch(ComputeShader cs, Vector2Int size, int kernel)
        {
            uint threadNumX, threadNumY, threadNumZ;
            cs.GetKernelThreadGroupSizes(kernel, out threadNumX, out threadNumY, out threadNumZ);
            cs.Dispatch(kernel, size.x / (int) threadNumX, size.y / (int) threadNumY, 1);
        }
        
        /// <summary>
        /// 从GPU端的Compute Shader中读取RenderTexture，绘制到CPU端的Texture2D中
        /// </summary>
        public static void ReadRTpixelsBackToCPU(RenderTexture src, Texture2D dst)
        {
            // 记录当前Active的RT
            RenderTexture currentActiveRT = RenderTexture.active;
            RenderTexture.active = src;
            dst.ReadPixels(new Rect(0, 0, dst.width, dst.height), 0, 0);
            // 恢复之前Active的RT
            RenderTexture.active = currentActiveRT;
        }
        
        /// <summary>
        /// 将HDR颜色分离为SDR颜色和强度
        /// </summary>
        public static void HDRToColorIntendity(Color hdr,out Color color,out float intensity)
        {
            // intensity = Mathf.Ceil(Mathf.Max(hdr.r, Mathf.Max(hdr.g, hdr.b)));
            // color = hdr / intensity;
            Vector3 v_hdr = new Vector3(hdr.r, hdr.g, hdr.b);
            float length = v_hdr.magnitude;
            v_hdr /= length;

            color = new Color(Mathf.Max(v_hdr.x, 0.01f), Mathf.Max(v_hdr.y, 0.01f), Mathf.Max(v_hdr.z, 0.01f), 1);
            intensity = Mathf.Max(length, 0.01f); // 保证主光源强度不会为0
            // intensity = length;
        }
    }
}