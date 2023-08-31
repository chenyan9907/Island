using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using FFTOceanCommon;

public class WavesCascade
{
    private readonly int kernel_CalculateInitialSpectrum;
    private readonly int kernel_CalculateConjugatedSpectrum;
    private readonly int kernel_CalculateAmplitudes;
    private readonly int kernel_FillResultTextures;
    
    // expression-bodied 实现只读属性
    public RenderTexture RTDisplacement => rt_Displacement;
    public RenderTexture RTDerivatives => rt_Derivatives;
    public RenderTexture RTTurbulence => rt_Turbulence;

    private readonly int size;
    private readonly ComputeShader cs_InitialSpectrum;
    private readonly ComputeShader cs_TimeDependentSpectrum;
    private readonly ComputeShader cs_TexturesMerger;
    private readonly FastFourierTransform fft;
    private readonly Texture2D tex_GaussianNoise;
    private readonly ComputeBuffer paramsBuffer;
    private readonly RenderTexture rt_InitialSpectrum;
    private readonly RenderTexture rt_waveData;

    private readonly RenderTexture rt_buffer;
    private readonly RenderTexture rt_DxDz;
    private readonly RenderTexture rt_DyDxz;
    private readonly RenderTexture rt_DyxDyz;
    private readonly RenderTexture rt_DxxDzz;

    private readonly RenderTexture rt_Displacement;
    private readonly RenderTexture rt_Derivatives;
    private readonly RenderTexture rt_Turbulence;

    private float lambda;

    public WavesCascade(int size,
        ComputeShader cs_InitialSpectrum,
        ComputeShader cs_TimeDependentSpectrum,
        ComputeShader cs_TexturesMerger,
        FastFourierTransform fft,
        Texture2D tex_GaussianNoise)
    {
        this.size = size;
        this.cs_InitialSpectrum = cs_InitialSpectrum;
        this.cs_TimeDependentSpectrum = cs_TimeDependentSpectrum;
        this.cs_TexturesMerger = cs_TexturesMerger;
        this.fft = fft;
        this.tex_GaussianNoise = tex_GaussianNoise;

        kernel_CalculateInitialSpectrum = cs_InitialSpectrum.FindKernel("CalculateInitialSpectrum");
        kernel_CalculateConjugatedSpectrum = cs_InitialSpectrum.FindKernel("CalculateConjugatedSpectrum");
        kernel_CalculateAmplitudes = cs_TimeDependentSpectrum.FindKernel("CalculateAmplitudes");
        kernel_FillResultTextures = cs_TexturesMerger.FindKernel("FillResultTextures");

        rt_InitialSpectrum = Utils.CreateRenderTexture(new Vector2Int(size, size));
        rt_waveData = Utils.CreateRenderTexture(new Vector2Int(size, size));
        rt_Displacement = Utils.CreateRenderTexture(new Vector2Int(size, size));
        rt_Derivatives = Utils.CreateRenderTexture(new Vector2Int(size, size), useMips: true);
        rt_Turbulence = Utils.CreateRenderTexture(new Vector2Int(size, size), useMips: true);
        paramsBuffer = new ComputeBuffer(2, 8 * sizeof(float)); //WaveSettings中SpectrumParams有8个float

        // 只需要两个通道
        rt_buffer = Utils.CreateRenderTexture(new Vector2Int(size, size), RenderTextureFormat.RGFloat);
        rt_DxDz = Utils.CreateRenderTexture(new Vector2Int(size, size), RenderTextureFormat.RGFloat);
        rt_DyDxz = Utils.CreateRenderTexture(new Vector2Int(size, size), RenderTextureFormat.RGFloat);
        rt_DyxDyz = Utils.CreateRenderTexture(new Vector2Int(size, size), RenderTextureFormat.RGFloat);
        rt_DxxDzz = Utils.CreateRenderTexture(new Vector2Int(size, size), RenderTextureFormat.RGFloat);
    }

    public void Dispose()
    {
        paramsBuffer?.Release();
    }

    public void CalcInitialSpectrum(WaveSettings waveSettings, float lengthScale, float cutoffLow, float cutoffHigh)
    {
        lambda = waveSettings.lambda;

        cs_InitialSpectrum.SetInt(Keys.k_Size, size);
        cs_InitialSpectrum.SetFloat(Keys.k_LengthScale, lengthScale);
        cs_InitialSpectrum.SetFloat(Keys.k_CutoffLow, cutoffLow);
        cs_InitialSpectrum.SetFloat(Keys.k_CutoffHigh, cutoffHigh);
        waveSettings.SetParametersToShader(cs_InitialSpectrum, kernel_CalculateInitialSpectrum, paramsBuffer);

        cs_InitialSpectrum.SetTexture(kernel_CalculateInitialSpectrum, Keys.k_H0K, rt_buffer);
        cs_InitialSpectrum.SetTexture(kernel_CalculateInitialSpectrum, Keys.k_WavesData, rt_waveData);
        cs_InitialSpectrum.SetTexture(kernel_CalculateInitialSpectrum, Keys.k_Noise, tex_GaussianNoise);
        cs_InitialSpectrum.Dispatch(kernel_CalculateInitialSpectrum, size / 8, size / 8, 1);

        cs_InitialSpectrum.SetTexture(kernel_CalculateConjugatedSpectrum, Keys.k_H0, rt_InitialSpectrum);
        cs_InitialSpectrum.SetTexture(kernel_CalculateConjugatedSpectrum, Keys.k_H0K, rt_buffer);
        cs_InitialSpectrum.Dispatch(kernel_CalculateConjugatedSpectrum, size / 8, size / 8, 1);
    }

    public void CalcWaveAtTime(float time)
    {
        cs_TimeDependentSpectrum.SetTexture(kernel_CalculateAmplitudes,Keys.k_DxDz,rt_DxDz);
        cs_TimeDependentSpectrum.SetTexture(kernel_CalculateAmplitudes,Keys.k_DyDxz,rt_DyDxz);
        cs_TimeDependentSpectrum.SetTexture(kernel_CalculateAmplitudes,Keys.k_DyxDyz,rt_DyxDyz);
        cs_TimeDependentSpectrum.SetTexture(kernel_CalculateAmplitudes,Keys.k_DxxDzz,rt_DxxDzz);
        cs_TimeDependentSpectrum.SetTexture(kernel_CalculateAmplitudes,Keys.k_H0,rt_InitialSpectrum);
        cs_TimeDependentSpectrum.SetTexture(kernel_CalculateAmplitudes,Keys.k_WavesData,rt_waveData);
        cs_TimeDependentSpectrum.SetFloat(Keys.k_Time,time);
        cs_TimeDependentSpectrum.Dispatch(kernel_CalculateAmplitudes, size / 8, size / 8, 1);

        fft.IFFT2D(rt_DxDz, rt_buffer, true, false, true);
        fft.IFFT2D(rt_DyDxz, rt_buffer, true, false, true);
        fft.IFFT2D(rt_DyxDyz, rt_buffer, true, false, true);
        fft.IFFT2D(rt_DxxDzz, rt_buffer, true, false, true);

        cs_TexturesMerger.SetFloat(Keys.k_DeltaTime, Time.deltaTime);
        cs_TexturesMerger.SetTexture(kernel_FillResultTextures,Keys.k_DxDz,rt_DxDz);
        cs_TexturesMerger.SetTexture(kernel_FillResultTextures,Keys.k_DyDxz,rt_DyDxz);
        cs_TexturesMerger.SetTexture(kernel_FillResultTextures,Keys.k_DyxDyz,rt_DyxDyz);
        cs_TexturesMerger.SetTexture(kernel_FillResultTextures,Keys.k_DxxDzz,rt_DxxDzz);
        cs_TexturesMerger.SetTexture(kernel_FillResultTextures,Keys.k_Displacement,rt_Displacement);
        cs_TexturesMerger.SetTexture(kernel_FillResultTextures,Keys.k_Derivatives,rt_Derivatives);
        cs_TexturesMerger.SetTexture(kernel_FillResultTextures,Keys.k_Turbulence,rt_Turbulence);
        cs_TexturesMerger.SetFloat(Keys.k_Lambda, lambda);
        cs_TexturesMerger.Dispatch(kernel_FillResultTextures, size / 8, size / 8, 1);
        
        rt_Derivatives.GenerateMips();
        rt_Turbulence.GenerateMips();
    }
}