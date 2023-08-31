using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using AtmosphericScatteringCommon;

[ExecuteInEditMode]
public class AtmosphericScatteringSkyboxSettings : MonoBehaviour
{
    [Header("Planet Settings")] public Light mainLight;

    [ColorUsage(false, true)] public Color incomingLight = Color.white;

    public float planetRadius = 6371000.0f;
    public float currentSceneHeight = 2000;

    [Header("Atomsphere Settings")] public float atomsphereHeight = 100000.0f;

    public float rayleighScaleHeight = 7994.0f;
    public Vector3 rayleighBeta = new Vector3(5.8f, 13.5f, 33.1f);
    public float rayleighScatterIntensity = 1f;
    public float rayleighExtinctionIntensity = 1f;
    public float mieScaleHeight = 1200.0f;
    public Vector3 mieBeta = new Vector3(3.9f, 3.9f, 3.9f);
    public float mieScatterIntensity = 1f;
    public float mieExtinctionIntensity = 1f;

    [Header("Sun Settings")] public float sunRenderIntensity = 1.0f;
    public float sunLightIntensity = 0.5f;
    public Color sunRenderColor = Color.white;
    [Range(-1, 1)] public float sunMieG = 0.98f;
    [Range(-1, 1)] public float mieG = 0.65f;
    public float distanceScale = 30;

    [Header("Precompute Lut")] public ComputeShader computeShader;
    
    public Vector2Int atmosphereDensityToTopLutSize = new Vector2Int(1024, 1024);
    [SerializeField] private RenderTexture rt_AtmosphereDensityToTopLUT;
    
    public Vector2Int sunParamsLutSize = new Vector2Int(1024, 1024);
    [SerializeField] private RenderTexture rt_SunParamsLUT;
    [SerializeField] private Texture2D tex_SunParamsLUT;
    [SerializeField] private int SunParamsLUTGranularity = 256;
    [SerializeField] private Color debugColor = Color.white;
    
    public int randomVectorSize = 256;
    [SerializeField] private Texture2D tex_RandomVectorLUT;
    [SerializeField] private RenderTexture rt_AmbientLight;
    [SerializeField] private Texture2D tex_AmbientLight;
    [SerializeField] [ColorUsage(false, true)] private Color m_AmbientColor;

    public Camera m_Camera;
    public Texture2D ditheringTex;
    public bool m_ShowFrustumCorners = false;
    public Vector3[] m_FrustumCorners = new Vector3[4];
    public Vector4[] m_FrustumCornersVec4 = new Vector4[4];

    private void Awake()
    {
        m_Camera = Camera.main;
    }
    
    private bool CheckComputeShader()
    {
        if (computeShader == null)
        {
            Debug.Log("没有设置Compute Shader！");
            return false;
        }

        return true;
    }

    /// <summary>
    /// 使用Compute Shader预计算任意高度任意天顶角下 到大气层顶端的累计大气密度Lut
    /// </summary>
    private void ComputeIntegrateAtmosphereDensityToTop()
    {
        // if (!CheckComputeShader()) return;
        Utility.CreateLUT(ref rt_AtmosphereDensityToTopLUT, atmosphereDensityToTopLutSize, RenderTextureFormat.RGFloat);
        int kernel = computeShader.FindKernel("CSIntegrateAtmosphereDensityToTop");
        computeShader.SetTexture(kernel, Keys.k_RWIntegrateAtmosphereDensityToTopLUT, rt_AtmosphereDensityToTopLUT);
        Utility.Dispatch(computeShader, atmosphereDensityToTopLutSize, kernel);
    }

    /// <summary>
    /// 使用Compute Shader预计算任意高度任意天顶角下 太阳强度、颜色参数Lut
    /// </summary>
    private void ComputeSunParams()
    {
        // if (!CheckComputeShader()) return;
        Utility.CreateLUT(ref rt_SunParamsLUT, sunParamsLutSize, RenderTextureFormat.DefaultHDR);
        int kernel = computeShader.FindKernel("CSPrecomputeSunParams");
        computeShader.SetTexture(kernel, Keys.k_RWSunParamsLUT, rt_SunParamsLUT);
        computeShader.SetTexture(kernel, Keys.k_AtmosphereDensityToTopLUT, rt_AtmosphereDensityToTopLUT);
        Utility.Dispatch(computeShader, sunParamsLutSize, kernel);
    }

    /// <summary>
    /// 使用太阳参数Lut，更新方向光参数
    /// </summary>
    private void UpdateMainLight()
    {
        if (mainLight == null) return;

        if (tex_SunParamsLUT == null)
        {
            tex_SunParamsLUT = new Texture2D(rt_SunParamsLUT.width, rt_SunParamsLUT.height, TextureFormat.RGBAHalf, false, true);
        }
        Utility.ReadRTpixelsBackToCPU(rt_SunParamsLUT, tex_SunParamsLUT);

        //获取mainLight局部坐标下的Forward，取反作为光的来向
        Vector3 lightDir = -mainLight.transform.forward;
        float cosAngle = Vector3.Dot(Vector3.up, lightDir) * 0.5f + 0.5f;
        float height = currentSceneHeight / atomsphereHeight;

        float cosAngle1 = cosAngle * (float)SunParamsLUTGranularity;//例如 cosAngle1 = 0.12 * 1024 = 122.88
        int index1 = Mathf.FloorToInt(cosAngle1);// index1 = 122
        float weight1 = cosAngle1 - index1;// weight1 = 0.88
        int index2 = index1 + 1;// index2 = 123
        float weight2 = 1 - weight1;//weight2 = 0.12
        
        Color col1 = tex_SunParamsLUT.GetPixel((int) ((float)index1/SunParamsLUTGranularity * tex_SunParamsLUT.width), (int) (height * tex_SunParamsLUT.height));
        Color col2 = tex_SunParamsLUT.GetPixel((int) ((float)index2/SunParamsLUTGranularity * tex_SunParamsLUT.width), (int) (height * tex_SunParamsLUT.height));
        Color col = tex_SunParamsLUT.GetPixel((int) (cosAngle * tex_SunParamsLUT.width), (int) (height * tex_SunParamsLUT.height));
        // Color col = col1 * weight1 + col2 * weight2;
        debugColor = col;
        Color lightColor;
        float intensity;
        Utility.HDRToColorIntendity(col, out lightColor, out intensity);

        mainLight.color = lightColor.gamma;
        sunRenderColor = mainLight.color;
        mainLight.intensity = intensity * sunLightIntensity;
        // RenderSun只是在天空盒上画出太阳的Scatter强度
        // 此处为太阳绘制赋予颜色，保证颜色与方向光颜色一致，保证日落时太阳同样变色
        Shader.SetGlobalColor(Keys.k_SunRenderColor, sunRenderColor);
    }

    /// <summary>
    /// 通过Random.onUnitSphere生成半球面上的随机向量
    /// </summary>
    private void GenerateRandomVectorLut()
    {
        tex_RandomVectorLUT = new Texture2D(randomVectorSize, 1, TextureFormat.RGBAHalf, false, false);
        Color[] colors = new Color[randomVectorSize];
        for (int i = 0; i < randomVectorSize; i++)
        {
            Vector3 vector = Random.onUnitSphere;
            colors[i] = new Color(vector.x, Mathf.Abs(vector.y), vector.z, 1);
        }
    
        tex_RandomVectorLUT.SetPixels(colors);
        tex_RandomVectorLUT.Apply();
        // Shader.SetGlobalTexture(Keys.k_RandomVectorLUT, tex_RandomVectorLUT);
    }
    
    /// <summary>
    /// 使用Compute Shader预计算天顶角在[0°, 90°]下的环境光颜色Lut
    /// </summary>
    private void ComputeAmbient()
    {
        Vector2Int size = new Vector2Int(randomVectorSize, 1);
        Utility.CreateLUT(ref rt_AmbientLight,size,RenderTextureFormat.DefaultHDR);
        int kernel = computeShader.FindKernel("CSIntegrateAmbientLight");
        computeShader.SetTexture(kernel, Keys.k_RandomVectorLUT, tex_RandomVectorLUT);
        computeShader.SetTexture(kernel, Keys.k_RWAmbientLightLUT, rt_AmbientLight);
        computeShader.SetTexture(kernel, Keys.k_AtmosphereDensityToTopLUT, rt_AtmosphereDensityToTopLUT);
        Utility.Dispatch(computeShader, size, kernel);
    }

    /// <summary>
    /// 根据境光颜色Lut，实时更新环境光
    /// </summary>
    private void UpdateAmbient()
    {
        if (tex_AmbientLight == null)
        {
            tex_AmbientLight = new Texture2D(rt_AmbientLight.width, rt_AmbientLight.height, TextureFormat.RGB24, false, true);
        }
        Utility.ReadRTpixelsBackToCPU(rt_AmbientLight,tex_AmbientLight);
        Vector3 lightDir = -mainLight.transform.forward;
        float cosAngle = Vector3.Dot(lightDir, Vector3.up);
        Color ambient;
        if (cosAngle >= 0)
        {
            ambient = tex_AmbientLight.GetPixel((int) (cosAngle * tex_AmbientLight.width), 0);
        }
        else
        {
            ambient = Color.black;
        }

        RenderSettings.ambientLight = ambient;
        m_AmbientColor = ambient;
    }

    private void SetupParams()
    {
        Shader.SetGlobalTexture(Keys.k_AtmosphereDensityToTopLUT, rt_AtmosphereDensityToTopLUT);
        // Shader.SetGlobalTexture(Keys., rt_SunOnSurfaceLUT);

        Shader.SetGlobalFloat(Keys.k_AtmosphereHeight, atomsphereHeight);
        Shader.SetGlobalFloat(Keys.k_PlanetRadius, planetRadius);
        Shader.SetGlobalFloat(Keys.k_CurrentSceneHeight, currentSceneHeight);
        Shader.SetGlobalVector(Keys.k_DensityScalarHeight, new Vector4(rayleighScaleHeight, mieScaleHeight, 0, 0));
        Vector3 rayleighBeta = this.rayleighBeta * 0.000001f;
        Vector3 mieBeta = this.mieBeta * 0.000001f;
        Shader.SetGlobalVector(Keys.k_RayleighSct, rayleighBeta * rayleighScatterIntensity);
        Shader.SetGlobalVector(Keys.k_RayleighExt, rayleighBeta * rayleighExtinctionIntensity);
        Shader.SetGlobalVector(Keys.k_MieSct, mieBeta * mieScatterIntensity);
        Shader.SetGlobalVector(Keys.k_MieExt, mieBeta * mieExtinctionIntensity);
        Shader.SetGlobalFloat(Keys.k_SunMieG, sunMieG);
        Shader.SetGlobalFloat(Keys.k_MieG, mieG);
        Shader.SetGlobalFloat(Keys.k_DistanceScale, distanceScale);
        Shader.SetGlobalColor(Keys.k_IncomingLight, incomingLight);
        Shader.SetGlobalFloat(Keys.k_SunRenderIntensity, sunRenderIntensity);
        Shader.SetGlobalColor(Keys.k_SunRenderColor, sunRenderColor);
        
        m_Camera.CalculateFrustumCorners(m_Camera.rect,m_Camera.farClipPlane,Camera.MonoOrStereoscopicEye.Mono,m_FrustumCorners);
        for (int i = 0; i < 4; i++)
        {
            m_FrustumCorners[i] = m_Camera.transform.TransformDirection(m_FrustumCorners[i]);
            m_FrustumCornersVec4[i] = m_FrustumCorners[i];
            if (m_ShowFrustumCorners)
                Debug.DrawRay(m_Camera.transform.position, m_FrustumCorners[i], Color.blue);
        }

        Shader.SetGlobalVectorArray(Keys.k_FrustumCorners, m_FrustumCornersVec4);
        Shader.SetGlobalTexture(Keys.k_DitheringTex, ditheringTex);
        Vector3 lightDir = -mainLight.transform.forward;
        Shader.SetGlobalVector(Keys.k_SunLightDir, lightDir);
    }

    void Start()
    {
        // SetupParams();
        // if (!CheckComputeShader()) return;
        // ComputeIntegrateAtmosphereDensityToTop();
        //
        // ComputeSunParams();
        // UpdateMainLight();
        //
        // GenerateRandomVectorLut();
        // ComputeAmbient();
        // UpdateAmbient();
    }

    void Update()
    {
        SetupParams();
        if (!CheckComputeShader()) return;
        ComputeIntegrateAtmosphereDensityToTop();
        
        ComputeSunParams();
        UpdateMainLight();
        
        GenerateRandomVectorLut();
        ComputeAmbient();
        UpdateAmbient();
        

        // UpdateMainLight();
        // UpdateAmbient();
    }
}