using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using FFTOceanCommon;

public struct SpectrumParams
{
    public float scale;
    public float angle;
    public float spreadBlend;
    public float swell;
    public float alpha;
    public float peakOmega;
    public float gamma;
    public float shortWavesFade;
}

[System.Serializable]
public struct DisplaySpectrumParams
{
    [Range(0, 1)] public float scale;
    public float windSpeed;
    public float windAngle;
    public float fetch;
    [Range(0, 1)] public float spreadBlend;
    [Range(0, 1)] public float swell;
    public float peakElevationFactor;
    public float shortWavesFade;
}

[CreateAssetMenu(fileName = "New Wave Settings", menuName = "Ocean/Wave Settings")]
public class WaveSettings : ScriptableObject
{
    public float g;
    public float depth;
    [Range(0, 1)]
    public float lambda;
    public DisplaySpectrumParams local;
    public DisplaySpectrumParams swell;
    
    SpectrumParams[] spectrums = new SpectrumParams[2];
    
    public void SetParametersToShader(ComputeShader shader, int kernelIndex, ComputeBuffer paramsBuffer)
    {
        shader.SetFloat(Keys.k_G, g);
        shader.SetFloat(Keys.k_Depth, depth);

        FillSettingsStruct(local, ref spectrums[0]);
        FillSettingsStruct(swell, ref spectrums[1]);

        paramsBuffer.SetData(spectrums);
        shader.SetBuffer(kernelIndex, Keys.k_Spectrums, paramsBuffer);
    }

    void FillSettingsStruct(DisplaySpectrumParams display, ref SpectrumParams settings)
    {
        settings.scale = display.scale;
        settings.angle = display.windAngle / 180 * Mathf.PI;
        settings.spreadBlend = display.spreadBlend;
        settings.swell = Mathf.Clamp(display.swell, 0.01f, 1);
        settings.alpha = JonswapAlpha(g, display.fetch, display.windSpeed);
        settings.peakOmega = JonswapPeakFrequency(g, display.fetch, display.windSpeed);
        settings.gamma = display.peakElevationFactor;
        settings.shortWavesFade = display.shortWavesFade;
    }
    
    float JonswapAlpha(float g, float fetch, float windSpeed)
    {
        return 0.076f * Mathf.Pow(g * fetch / windSpeed / windSpeed, -0.22f);
    }

    float JonswapPeakFrequency(float g, float fetch, float windSpeed)
    {
        return 22 * Mathf.Pow(windSpeed * fetch / g / g, -0.33f);
    }
}