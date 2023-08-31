using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

namespace FFTOceanCommon
{
    public static class Keys
    {
        // cs_FFT
        public static readonly int k_PrecomputeBuffer = Shader.PropertyToID("PrecomputeBuffer");
        public static readonly int k_PrecomputeData = Shader.PropertyToID("PrecomputeData");
        public static readonly int k_Buffer0 = Shader.PropertyToID("Buffer0");
        public static readonly int k_Buffer1 = Shader.PropertyToID("Buffer1");
        public static readonly int k_Size = Shader.PropertyToID("Size");
        public static readonly int k_Step = Shader.PropertyToID("Step");
        public static readonly int k_PingPong = Shader.PropertyToID("PingPong");
        
        // cs_InitialSpectrum
        public static readonly int k_H0 = Shader.PropertyToID("H0");
        public static readonly int k_H0K = Shader.PropertyToID("H0K");
        public static readonly int k_WavesData = Shader.PropertyToID("WavesData");
        public static readonly int k_Noise = Shader.PropertyToID("Noise");
        public static readonly int k_LengthScale = Shader.PropertyToID("LengthScale");
        public static readonly int k_CutoffHigh = Shader.PropertyToID("CutoffHigh");
        public static readonly int k_CutoffLow = Shader.PropertyToID("CutoffLow");
        public static readonly int k_G = Shader.PropertyToID("GravityAcceleration");
        public static readonly int k_Depth = Shader.PropertyToID("Depth");
        public static readonly int k_Spectrums = Shader.PropertyToID("Spectrums");
        
        // cs_TimeDependentSpectrum
        public static readonly int k_DxDz = Shader.PropertyToID("Dx_Dz");
        public static readonly int k_DyDxz = Shader.PropertyToID("Dy_Dxz");
        public static readonly int k_DyxDyz = Shader.PropertyToID("Dyx_Dyz");
        public static readonly int k_DxxDzz = Shader.PropertyToID("Dxx_Dzz");
        public static readonly int k_Time = Shader.PropertyToID("Time");
        
        // cs_WaveTextureMerger
        public static readonly int k_Displacement = Shader.PropertyToID("Displacement");
        public static readonly int k_Derivatives = Shader.PropertyToID("Derivatives");
        public static readonly int k_Turbulence = Shader.PropertyToID("Turbulence");
        public static readonly int k_Lambda = Shader.PropertyToID("Lambda");
        public static readonly int k_DeltaTime = Shader.PropertyToID("DeltaTime");
    }

    public static class Utils
    {
        public static RenderTexture CreateRenderTexture(Vector2Int size,
            RenderTextureFormat format = RenderTextureFormat.ARGBFloat,
            FilterMode filterMode = FilterMode.Trilinear,
            bool useMips = false)
        {
            RenderTexture rt = new RenderTexture(size.x, size.y, 0, format, RenderTextureReadWrite.Linear);
            rt.useMipMap = useMips;
            rt.autoGenerateMips = false;
            rt.anisoLevel = 6;
            rt.filterMode = filterMode;
            rt.wrapMode = TextureWrapMode.Repeat;
            rt.enableRandomWrite = true;
            rt.Create();
            return rt;
        }

        public static Texture2D GetNoiseTexture(int size)
        {
            string filename = "GaussianNoiseTexture" + size.ToString() + "x" + size.ToString();
            Texture2D noise = Resources.Load<Texture2D>("GaussianNoiseTexture/" + filename);
            return noise ? noise : GenerateNoiseTexture(size, true);
        }

        private static Texture2D GenerateNoiseTexture(int size, bool saveToFile)
        {
            Texture2D noise = new Texture2D(size, size, TextureFormat.RGFloat, false, true);
            noise.filterMode = FilterMode.Point;
            for (int i = 0; i < size; i++)
            {
                for (int j = 0; j < size; j++)
                {
                    noise.SetPixel(i, j, new Vector4(NormalRandom(), NormalRandom()));
                }
            }
            noise.Apply();
            
            #if UNITY_EDITOR
            if (saveToFile)
            {
                string filename = "GaussianNoiseTexture" + size.ToString() + "x" + size.ToString();
                string path = "Assets/Resources/GaussianNoiseTextures/";
                AssetDatabase.CreateAsset(noise, path + filename + ".asset");
            }
            #endif
            return noise;
        }

        private static float NormalRandom()
        {
            return Mathf.Cos(2 * Mathf.PI * Random.value) * Mathf.Sqrt(-2 * Mathf.Log(Random.value));
        }

        public static void ReadbackToCPU(RenderTexture src, Texture2D dst)
        {
            RenderTexture currentRT = RenderTexture.active;
            RenderTexture.active = src;
            dst.ReadPixels(new Rect(0, 0, dst.width, dst.height), 0, 0);
            RenderTexture.active = currentRT;
        }
    }
}