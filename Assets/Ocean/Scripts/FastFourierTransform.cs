using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using FFTOceanCommon;

public class FastFourierTransform
{
    private readonly int kernel_PrecomputeTwiddle;
    private readonly int kernel_HorizontalFFT;
    private readonly int kernel_VerticalFFT;
    private readonly int kernel_HorizontalIFFT;
    private readonly int kernel_VerticalIFFT;
    private readonly int kernel_Scale;
    private readonly int kernel_Permute;

    private readonly int size;
    private readonly ComputeShader cs_FFT;
    private readonly RenderTexture rt_PrecomputedData;

    public FastFourierTransform(int size, ComputeShader cs_FFT)
    {
        this.size = size;
        this.cs_FFT = cs_FFT;
        this.rt_PrecomputedData = PrecomputeTwiddleFactorsAndInputIndices();

        kernel_PrecomputeTwiddle = cs_FFT.FindKernel("PrecomputeTwiddleFactorsAndInputIndices");
        kernel_HorizontalFFT = cs_FFT.FindKernel("HorizontalFFT");
        kernel_VerticalFFT = cs_FFT.FindKernel("VerticalFFT");
        kernel_HorizontalIFFT = cs_FFT.FindKernel("HorizontalIFFT");
        kernel_VerticalIFFT = cs_FFT.FindKernel("VerticalIFFT");
        kernel_Scale = cs_FFT.FindKernel("Scale");
        kernel_Permute = cs_FFT.FindKernel("Permute");
    }

    public void FFT2D(RenderTexture input, RenderTexture buffer, bool outputToInput = false)
    {
        int stageSize = (int) Mathf.Log(size, 2);
        bool pingPong = false;

        cs_FFT.SetTexture(kernel_HorizontalFFT, Keys.k_PrecomputeData, rt_PrecomputedData);
        cs_FFT.SetTexture(kernel_HorizontalFFT, Keys.k_Buffer0, input);
        cs_FFT.SetTexture(kernel_HorizontalFFT, Keys.k_Buffer1, buffer);
        for (int i = 0; i < stageSize; i++)
        {
            pingPong = !pingPong;
            cs_FFT.SetInt(Keys.k_Step,i);
            cs_FFT.SetBool(Keys.k_PingPong, pingPong);
            cs_FFT.Dispatch(kernel_HorizontalFFT, size / 8, size / 8, 1);
        }
        
        cs_FFT.SetTexture(kernel_VerticalFFT, Keys.k_PrecomputeData, rt_PrecomputedData);
        cs_FFT.SetTexture(kernel_VerticalFFT, Keys.k_Buffer0, input);
        cs_FFT.SetTexture(kernel_VerticalFFT, Keys.k_Buffer1, buffer);
        for (int i = 0; i < stageSize; i++)
        {
            pingPong = !pingPong;
            cs_FFT.SetInt(Keys.k_Step,i);
            cs_FFT.SetBool(Keys.k_PingPong, pingPong);
            cs_FFT.Dispatch(kernel_VerticalFFT, size / 8, size / 8, 1);
        }
        
        if (pingPong && outputToInput)
        {
            Graphics.Blit(buffer, input);
        }

        if (!pingPong && !outputToInput)
        {
            Graphics.Blit(input, buffer);
        }
    }

    public void IFFT2D(RenderTexture input, RenderTexture buffer, bool outputToInput = false, bool scale = true, bool permute = false)
    {
        int stageSize = (int) Mathf.Log(size, 2);
        bool pingPong = false;
        
        cs_FFT.SetTexture(kernel_HorizontalIFFT, Keys.k_PrecomputeData, rt_PrecomputedData);
        cs_FFT.SetTexture(kernel_HorizontalIFFT, Keys.k_Buffer0, input);
        cs_FFT.SetTexture(kernel_HorizontalIFFT, Keys.k_Buffer1, buffer);
        for (int i = 0; i < stageSize; i++)
        {
            pingPong = !pingPong;
            cs_FFT.SetInt(Keys.k_Step, i);
            cs_FFT.SetBool(Keys.k_PingPong, pingPong);
            cs_FFT.Dispatch(kernel_HorizontalIFFT, size / 8, size / 8, 1);
        }

        cs_FFT.SetTexture(kernel_VerticalIFFT, Keys.k_PrecomputeData, rt_PrecomputedData);
        cs_FFT.SetTexture(kernel_VerticalIFFT, Keys.k_Buffer0, input);
        cs_FFT.SetTexture(kernel_VerticalIFFT, Keys.k_Buffer1, buffer);
        for (int i = 0; i < stageSize; i++)
        {
            pingPong = !pingPong;
            cs_FFT.SetInt(Keys.k_Step, i);
            cs_FFT.SetBool(Keys.k_PingPong, pingPong);
            cs_FFT.Dispatch(kernel_VerticalIFFT, size / 8, size / 8, 1);
        }

        if (pingPong && outputToInput)
        {
            Graphics.Blit(buffer, input);
        }

        if (!pingPong && !outputToInput)
        {
            Graphics.Blit(input, buffer);
        }
        
        if (permute)
        {
            cs_FFT.SetInt(Keys.k_Size, size);
            cs_FFT.SetTexture(kernel_Permute, Keys.k_Buffer0, outputToInput ? input : buffer);
            cs_FFT.Dispatch(kernel_Permute, size / 8, size / 8, 1);
        }
        
        if (scale)
        {
            cs_FFT.SetInt(Keys.k_Size, size);
            cs_FFT.SetTexture(kernel_Scale, Keys.k_Buffer0, outputToInput ? input : buffer);
            cs_FFT.Dispatch(kernel_Scale, size / 8, size / 8, 1);
        }
    }
    
    RenderTexture PrecomputeTwiddleFactorsAndInputIndices()
    {
        int stageSize = (int)Mathf.Log(size, 2);
        RenderTexture rt_PrecomputeTwiddle = Utils.CreateRenderTexture(new Vector2Int(stageSize, size), RenderTextureFormat.ARGBFloat, FilterMode.Point);

        cs_FFT.SetInt(Keys.k_Size, size);
        cs_FFT.SetTexture(kernel_PrecomputeTwiddle, Keys.k_PrecomputeBuffer, rt_PrecomputeTwiddle);
        cs_FFT.Dispatch(kernel_PrecomputeTwiddle, stageSize, size / 2 / 8, 1);
        return rt_PrecomputeTwiddle;
    }
}
