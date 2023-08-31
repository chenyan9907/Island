using FFTOceanCommon;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Serialization;

// [ExecuteInEditMode]

public class WaveGenerator : MonoBehaviour
{
    public WavesCascade cascade0;
    public WavesCascade cascade1;
    public WavesCascade cascade2;

    [SerializeField] [Range(1, 10)] private int powerOfSize = 8;

    [Tooltip("Need to restart")] [SerializeField]
    private int size;

    [SerializeField] private WaveSettings waveSettings;
    [SerializeField] private float lengthScale0 = 250;
    [SerializeField] private float lengthScale1 = 20;
    [SerializeField] private float lengthScale2 = 5;

    [FormerlySerializedAs("csFFT")] [SerializeField]
    private ComputeShader cs_FFT;

    [SerializeField] private ComputeShader cs_InitialSpectrum;
    [SerializeField] private ComputeShader cs_TimeDependentSpectrum;
    [SerializeField] private ComputeShader cs_TexturesMerger;

    private Texture2D tex_GaussianNoise;
    private FastFourierTransform fft;
    private Texture2D tex_ReadBack;


    private void Awake()
    {
        size = (int) Mathf.Pow(2, powerOfSize);
        fft = new FastFourierTransform(size, cs_FFT);
        tex_GaussianNoise = Utils.GetNoiseTexture(size);

        cascade0 = new WavesCascade(size, cs_InitialSpectrum, cs_TimeDependentSpectrum, cs_TexturesMerger, fft, tex_GaussianNoise);
        cascade1 = new WavesCascade(size, cs_InitialSpectrum, cs_TimeDependentSpectrum, cs_TexturesMerger, fft, tex_GaussianNoise);
        cascade2 = new WavesCascade(size, cs_InitialSpectrum, cs_TimeDependentSpectrum, cs_TexturesMerger, fft, tex_GaussianNoise);

        InitializeCascade();

        tex_ReadBack = new Texture2D(size, size, TextureFormat.RGBAFloat, false);
    }

    void InitializeCascade()
    {
        float boundary1 = 2 * Mathf.PI / lengthScale1 * 6f;
        float boundary2 = 2 * Mathf.PI / lengthScale2 * 6f;
        cascade0.CalcInitialSpectrum(waveSettings, lengthScale0, 0.0001f, boundary1);
        cascade1.CalcInitialSpectrum(waveSettings, lengthScale1, boundary1, boundary2);
        cascade2.CalcInitialSpectrum(waveSettings, lengthScale2, boundary2, 9999);

        //待修改
        Shader.SetGlobalFloat("LengthScale0", lengthScale0);
        Shader.SetGlobalFloat("LengthScale1", lengthScale1);
        Shader.SetGlobalFloat("LengthScale2", lengthScale2);
    }

    private void Update()
    {
        size = (int) Mathf.Pow(2, powerOfSize);

        InitializeCascade();

        cascade0.CalcWaveAtTime(Time.time);
        cascade1.CalcWaveAtTime(Time.time);
        cascade2.CalcWaveAtTime(Time.time);

        // Utils.ReadbackToCPU(cascade0.RTDisplacement, tex_ReadBack);
    }

    private void OnDestroy()
    {
        cascade0.Dispose();
        cascade1.Dispose();
        cascade2.Dispose();
    }
}