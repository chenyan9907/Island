using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class AtmosphericScattering : MonoBehaviour
{
    public Material material;
    public Material skyboxMat;

    public RenderTexture _AtmosphereDensityLUT;

    private const float AtmosphereHeight = 80000.0f;
    private const float PlanetRadius = 6371000.0f;
    private readonly Vector4 DensityScale = new Vector4(7994.0f, 1200.0f, 0, 0);
    private readonly Vector4 RayleighSct = new Vector4(5.8f, 13.5f, 33.1f, 0.0f) * 0.000001f;
    private readonly Vector4 MieSct = new Vector4(3.9f, 3.9f, 3.9f, 0.0f) * 0.00001f;

    // Start is called before the first frame update
    void Start()
    {
        material.SetFloat("_AtmosphereHeight", AtmosphereHeight);
        material.SetFloat("_PlanetRadius", PlanetRadius);
        material.SetVector("_DensityScalarHeight", DensityScale);
        PrecomputeParticleDensity();
    }

    // Update is called once per frame
    void Update()
    {
    }

    private void PrecomputeParticleDensity()
    {
        if (_AtmosphereDensityLUT == null)
        {
            _AtmosphereDensityLUT = new RenderTexture(1024, 1024, 0, RenderTextureFormat.RGFloat, RenderTextureReadWrite.Linear);
            _AtmosphereDensityLUT.name = "ParticleDensityLUT";
            _AtmosphereDensityLUT.filterMode = FilterMode.Bilinear;
            _AtmosphereDensityLUT.Create();
        }

        Texture nullTexture = null;
        Graphics.Blit(nullTexture, _AtmosphereDensityLUT, material, 0);

        material.SetTexture("_AtmosphereDensityLUT", _AtmosphereDensityLUT);
        skyboxMat.SetTexture("_AtmosphereDensityLUT", _AtmosphereDensityLUT);
    }

    private void GenParticleDensityLut()
    {
        RenderTexture lut;
        int lutSize = 1024;
        var previousRenderTexture = RenderTexture.active;
        // Material lutMat = new Material(Shader.Find("Custom/SkinLut"));

        // lutMat.SetFloat("_MaxRadius", filterRadius);
        // lutMat.SetVector("_ShapeParam", shapeParam);
        lut = new RenderTexture(lutSize, lutSize, 0, RenderTextureFormat.RGFloat, RenderTextureReadWrite.Linear);
        CommandBuffer cmd = new CommandBuffer();
        RenderTexture.active = lut;
        cmd.SetRenderTarget(lut);
        cmd.SetViewport(new Rect(0, 0, lutSize, lutSize));
        cmd.ClearRenderTarget(true, true, Color.clear);
        cmd.SetViewProjectionMatrices(Matrix4x4.identity, Matrix4x4.identity);
        cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, material, 0, 0);
        Graphics.ExecuteCommandBuffer(cmd);
        cmd.Release();
        // DestroyImmediate(material);
        Texture2D result = new Texture2D(lutSize, lutSize, TextureFormat.RGFloat, false);
        result.ReadPixels(new Rect(0, 0, lutSize, lutSize), 0, 0, false);
        result.Apply(false);
        RenderTexture.active = previousRenderTexture;


        string path = (EditorUtility.SaveFilePanel("", "Assets", "ParticleDensityLut", "exr"));
        if (!string.IsNullOrEmpty(path))
        {
            Debug.Log("路径+" + path);
            File.WriteAllBytes(path, result.EncodeToEXR());
            AssetDatabase.Refresh();
        }
    }
}