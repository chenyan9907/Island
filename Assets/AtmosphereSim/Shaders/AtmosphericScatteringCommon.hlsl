CBUFFER_START(UnityPerMaterial)
    float _AtmosphereHeight;
    float _PlanetRadius;
    float _CurrentSceneHeight;
    float2 _DensityScalarHeight;

    float3 _RayleighSct;
    float3 _RayleighExt;
    float3 _MieSct;
    float3 _MieExt;
    float _SunMieG;
    float _MieG;
    float _DistanceScale;

    float4 _IncomingLight;
    float _SunRenderIntensity;
    float4 _SunRenderColor;
CBUFFER_END

TEXTURE2D(_AtmosphereDensityToTopLUT);
SAMPLER(sampler_AtmosphereDensityToTopLUT);
TEXTURE2D(_LightShaft);
SAMPLER(sampler_LightShaft);
// TEXTURE2D(_RandomVectorLUT);
// SAMPLER(sampler_RandomVectorLUT);


//-----------------------------------------------------------------------------------------
// 空间直线与球体求交
// 空间直线点向式表达：r(t)=p+td，球体隐函数：|o-c|=r，直线与球面相交=>解方程|r(t)-c|=r，化简得一元二次方程，t为变量
// 返回t的值
//-----------------------------------------------------------------------------------------
float2 RaySphereIntersection(float3 rayPos, float3 rayDir, float3 sphereCenter, float sphereRadius)
{
    float3 p_c = rayPos - sphereCenter;
    float a = dot(rayDir, rayDir);
    float b = 2.0 * dot(rayDir, p_c);
    float c = dot(p_c, p_c) - (sphereRadius * sphereRadius);
    float d = b * b - 4 * a * c;
    if (d < 0)
    {
        return -1;
    }
    else
    {
        d = sqrt(d);
        return float2(-b - d, -b + d) / (2.0 * a);
    }
}


//-----------------------------------------------------------------------------------------
// height下的大气密度
//-----------------------------------------------------------------------------------------
float AtmosphereDensityAtHeight(float height, float scalarHeight)
{
    return exp(-height / scalarHeight);
}

//返回height高度下，瑞利散射x和米氏散射y的大气密度
float2 AtmosphereDensityAtHeight(float height, float2 scalarHeight)
{
    return exp(-height.xx / scalarHeight);
}

//-----------------------------------------------------------------------------------------
// 瑞利散射和米氏散射的相位函数
//-----------------------------------------------------------------------------------------
float RayleighPhaseFunc(float cosAngle)
{
    return 3.0 / (16.0 * PI) * (1.0 + cosAngle * cosAngle);
}

float MiePhaseFunc(float g, float cosAngle)
{
    float g2 = g * g;
    return 3.0 / (8.0 * PI) * (1.0 - g2) / (2.0 + g2) * (1.0 + cosAngle * cosAngle) / pow(1 + g2 - 2.0 * g * cosAngle, 3.0 / 2.0);
}

//-----------------------------------------------------------------------------------------
// 计算从某一高度出发，到达大气层的路径的大气密度积分
//-----------------------------------------------------------------------------------------
float2 PrecomputeAtmosphereDensityToTop(float3 rayStart, float3 rayDir)
{
    float3 planetCenter = float3(0, -_PlanetRadius, 0);
    float stepCount = 256;
    float2 intersection = RaySphereIntersection(rayStart, rayDir, planetCenter, _PlanetRadius);
    if (intersection.x > 0)
    {
        return 1e+20;
    }
    intersection = RaySphereIntersection(rayStart, rayDir, planetCenter, _PlanetRadius + _AtmosphereHeight);
    float3 rayEnd = rayStart + rayDir * intersection.y;

    float3 step = (rayEnd - rayStart) / stepCount;
    float stepSize = length(step);
    float2 density = 0;
    //s取0.5表示取当前积分线段的中间
    for (float s = 0.5; s < stepCount; s += 1.0)
    {
        float3 position = rayStart + step * s;
        float height = abs(length(position - planetCenter) - _PlanetRadius);
        float2 currentDensity = AtmosphereDensityAtHeight(height, _DensityScalarHeight);
        density += currentDensity * stepSize;
    }
    return density;
}

//-----------------------------------------------------------------------------------------
// 计算从当前位置到大气顶部的累计大气密度
//-----------------------------------------------------------------------------------------
void GetAtmosphereDensityToTop(float3 position, float3 planetCenter, float3 lightDir, out float2 currentDensity, out float2 densityToTop)
{
    float height = length(position - planetCenter) - _PlanetRadius;
    currentDensity = AtmosphereDensityAtHeight(height, _DensityScalarHeight);
    float cosAngle = dot(normalize(position - planetCenter), lightDir); //position-planetCenter => (0,1,0)
    densityToTop = SAMPLE_TEXTURE2D_LOD(_AtmosphereDensityToTopLUT, sampler_AtmosphereDensityToTopLUT, float2(cosAngle*0.5+0.5,height/_AtmosphereHeight), 0).rg;
}

void ComputeCurrentInScattering(float2 currentDensity, float2 densityCP, float2 densityPA, out float3 currentInScatteringR, out float3 currentInScatteringM)
{
    // //注意，有出入
    // float2 densityCPA = densityCP + densityPA;
    // float3 TR = exp(-_RayleighSct * densityCPA.x);
    // float3 TM = exp(-_MieSct * densityCPA.y);
    // currentInScatteringR = currentDensity.x * TR;
    // currentInScatteringM = currentDensity.y * TM;

    float2 densityCPA = densityCP + densityPA;
    float3 Tr = densityCPA.x * _RayleighExt;
    float3 Tm = densityCPA.y * _MieExt;
    float3 extinction = exp(-(Tr + Tm));
    currentInScatteringR = currentDensity.x * extinction;
    currentInScatteringM = currentDensity.y * extinction;
}

float3 RenderSun(float3 scatterRayleigh, float cosAngle)
{
    return scatterRayleigh * MiePhaseFunc(_SunMieG, cosAngle) * 0.00003;
}

float4 IntegrateInscattering(float3 rayStart, float3 rayDir, float rayLength, float3 planetCenter, float distanceScale, float3 lightDir, float sampleCount, out float3 extinction)
{
    float3 step = rayDir * (rayLength / sampleCount);
    float stepSize = length(step) * distanceScale;

    // A为相机所在点（起点），B为视线与大气/地表交点（终点）
    // C为光线与大气层交点（光线射入点）
    // P为AB上的当前积分点
    float2 densityPA = 0;
    float3 scatterRayleigh = 0;
    float3 scatterMie = 0;

    float2 currentDensity = 0;
    float2 densityCP = 0;

    float2 prevDensity = 0;
    float3 prevInScatteringR = 0;
    float3 prevInScatteringM = 0;

    // 积分循环开始前，P处于A点，先获取A点处的大气密度（积分梯形法则需要），CP的光学深度
    GetAtmosphereDensityToTop(rayStart, planetCenter, lightDir, prevDensity, densityCP);
    // 计算P点处的
    ComputeCurrentInScattering(prevDensity, densityCP, densityPA, prevInScatteringR, prevInScatteringM);

    [loop]
    for (float s = 1.0; s < sampleCount; s += 1.0)
    {
        float3 currentPos = rayStart + step * s;
        GetAtmosphereDensityToTop(currentPos, planetCenter, lightDir, currentDensity, densityCP);
        densityPA += (prevDensity + currentDensity) * stepSize / 2.0; //积分梯形法则
        prevDensity = currentDensity;

        float3 currentInScatteringR, currentInScatteringM;
        ComputeCurrentInScattering(currentDensity, densityCP, densityPA, currentInScatteringR, currentInScatteringM);
        scatterRayleigh += (prevInScatteringR + currentInScatteringR) * stepSize / 2.0; //积分梯形法则
        scatterMie += (prevInScatteringM + currentInScatteringM) * stepSize / 2.0;
        prevInScatteringR = currentInScatteringR;
        prevInScatteringM = currentInScatteringM;
    }

    float cosAngle = dot(rayDir, lightDir);
    //经过相位函数便宜过后的散射
    float3 scatteredR = RayleighPhaseFunc(cosAngle) * scatterRayleigh;
    float3 scatteredM = MiePhaseFunc(_MieG, cosAngle) * scatterMie;
    // float3 lightInScatter = (_RayleighSct * scatteredR + _MieSct * scatteredM);
    float3 lightInScatter = (_RayleighSct * scatteredR + _MieSct * scatteredM) * _IncomingLight.xyz;
    
    // 绘制太阳时，乘上规格化颜色分量，为太阳染色
    // lightInScatter += RenderSun(scatterRayleigh, cosAngle) * _SunRenderIntensity * normalize(_SunRenderColor.xyz);
    lightInScatter += RenderSun(scatterRayleigh, cosAngle) * _SunRenderIntensity;
    //这一步不应该存在（？）
    // 根据太阳光Lut改变天空盒整体色调
    lightInScatter *= _SunRenderColor.xyz * 2;
    
    extinction = exp(-(densityPA.x * _RayleighExt + densityPA.y * _MieExt));
    // return float4(cosAngle,0,0, 1);
    return float4(lightInScatter, 1);
}
