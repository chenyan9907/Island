struct SampleInfo
{
    float3 position;
    float earthRadius;
    float2 cloudHeightMinMax;
    float weatherTexTiling;
    float detailIntensity;
    float cloudCoverage;
    float3 stratusParams;
    float3 cumulusParams;
    float densityScale;

    float cloudAbsorb;

    float3 windDir;
    float windSpeed;
};

struct CloudParams
{
    float density;
    float absorptivity;
};

TEXTURE2D(_WeatherTex);
SAMPLER(sampler_WeatherTex);
TEXTURE3D(_CloudBaseTex);
SAMPLER(sampler_CloudBaseTex);
TEXTURE3D(_CloudDetailTex);
SAMPLER(sampler_CloudDetailTex);

//同空间直线与球体相交，a项为1故省略，不相交或相切时，xy返回0
//限制距离为正，即向rayDir方向看
float2 RaySphereDst(float3 sphereCenter, float sphereRadius, float3 rayStart, float3 rayDir)
{
    float3 oc = rayStart - sphereCenter;
    float b = dot(rayDir, oc);
    float c = dot(oc, oc) - sphereRadius * sphereRadius;
    float t = b * b - c; //t > 0有两个交点, = 0 相切， < 0 不相交

    float delta = sqrt(max(t, 0));
    float dstToSphere = max(-b - delta, 0);
    float dstInSphere = max(-b + delta - dstToSphere, 0);
    return float2(dstToSphere, dstInSphere);
}

float2 RayCloudDst(float3 sphereCenter, float sphereRadius, float heightMin, float heightMax, float3 rayStart, float3 rayDir, bool inCloud = false)
{
    float2 cloudDstHeightMin = RaySphereDst(sphereCenter, sphereRadius + heightMin, rayStart, rayDir);
    float2 cloudDstHeightMax = RaySphereDst(sphereCenter, sphereRadius + heightMax, rayStart, rayDir);

    float dstToCloudLayer = 0;
    float dstInCloudLayer = 0;

    if (!inCloud)
    {
        //在云层下
        if (rayStart.y <= heightMin)
        {
            //判断是否为向天上看
            float3 startPos = rayStart + rayDir * cloudDstHeightMin.y;
            if (startPos.y > 0)
            {
                dstToCloudLayer = cloudDstHeightMin.y;
                dstInCloudLayer = cloudDstHeightMax.y - cloudDstHeightMin.y;
            }
            return float2(dstToCloudLayer, dstInCloudLayer);
        }
        //在云层中
        if (rayStart.y > heightMin && rayStart.y <= heightMax)
        {
            dstToCloudLayer = 0;
            //向下看的话去Min.x，向上看的话取Max.y
            dstInCloudLayer = cloudDstHeightMin.y > 0 ? cloudDstHeightMin.x : cloudDstHeightMax.y;
            return float2(dstToCloudLayer, dstInCloudLayer);
        }
        //在云层上
        dstToCloudLayer = cloudDstHeightMax.x;
        dstInCloudLayer = cloudDstHeightMin.y > 0 ? cloudDstHeightMin.x - dstToCloudLayer : cloudDstHeightMax.y;
    }
    else
    {
        //一定在云层中时使用此分支
        dstToCloudLayer = 0;
        dstInCloudLayer = cloudDstHeightMin.y > 0 ? cloudDstHeightMin.x : cloudDstHeightMax.y;
    }
    return float2(dstToCloudLayer, dstInCloudLayer);
}

//重映射
float Remap(float original_value, float original_min, float original_max, float new_min, float new_max)
{
    return new_min + ((original_value - original_min) / (original_max - original_min)) * (new_max - new_min);
}

//获取云类型密度
float GetCloudTypeDensity(float heightFraction, float cloud_min, float cloud_max, float feather)
{
    //云的底部羽化需要弱一些，所以乘0.5
    return saturate(Remap(heightFraction, cloud_min, cloud_min + feather * 0.5, 0, 1)) * saturate(Remap(heightFraction, cloud_max - feather, cloud_max, 1, 0));
}

//在三个值间进行插值，x<=offset时，在value1和value2中插值；x>offset时，在value2和value3中插值
float Interpolation3(float value1, float value2, float value3, float x, float offset = 0.5)
{
    offset = clamp(offset, 0.0001, 0.9999);
    return lerp(lerp(value1, value2, min(x, offset) / offset), value3, max(0, x - offset) / (1.0 - offset));
}

//重载float3类型
float3 Interpolation3(float3 value1, float3 value2, float3 value3, float x, float offset = 0.5)
{
    offset = clamp(offset, 0.0001, 0.9999);
    return lerp(lerp(value1, value2, min(x, offset) / offset), value3, max(0, x - offset) / (1.0 - offset));
}

CloudParams SampleCloudDensity(SampleInfo sif, bool sampleDetail = false)
{
    CloudParams o;

    // 获取当前高度在云层范围中的高度比，范围在[0, 1]
    float heightRatio = (sif.position.y - sif.cloudHeightMinMax.x) / (sif.cloudHeightMinMax.y - sif.cloudHeightMinMax.x);

    float3 wind = sif.windDir * sif.windSpeed * _Time.y;
    float3 position = sif.position + wind * 100;

    // r 密度, g 吸收率, b 云类型(0~1 => 层云~积云)
    float2 weatherTexUV = sif.position.xz * sif.weatherTexTiling;
    float4 weatherParams = SAMPLE_TEXTURE2D_LOD(_WeatherTex, sampler_WeatherTex, weatherTexUV * 0.000001 + wind.xz * 0.01, 0);
    weatherParams.r = Interpolation3(0, weatherParams.r, 1, sif.cloudCoverage);
    weatherParams.b = Interpolation3(0, weatherParams.b, 1, sif.cloudCoverage);
    if (weatherParams.r <= 0)
    {
        o.density = 0;
        o.absorptivity = 1;
        return o;
    }

    float stratusDensity = GetCloudTypeDensity(heightRatio, sif.stratusParams.x, sif.stratusParams.y, sif.stratusParams.z);
    float cumulusDensity = GetCloudTypeDensity(heightRatio, sif.cumulusParams.x, sif.cumulusParams.y, sif.cumulusParams.z);
    float mixedCloudDensity = lerp(stratusDensity, cumulusDensity, weatherParams.b);
    if (mixedCloudDensity <= 0)
    {
        o.density = 0;
        o.absorptivity = 1;
        return o;
    }

    float cloudAbsorption = Interpolation3(0, weatherParams.g, 1, sif.cloudAbsorb);

    float4 baseTex = SAMPLE_TEXTURE3D_LOD(_CloudBaseTex, sampler_CloudBaseTex, position * 0.0001, 0);
    float baseTexFBM = dot(baseTex.gba, float3(0.5, 0.25, 0.125));
    //对基础形状添加细节，通过Remap可以不影响基础形状下添加细节
    float baseShape = Remap(baseTex.r, saturate((1.0 - baseTexFBM) * 0.5), 1.0, 0, 1.0);

    float cloudDensity = baseShape * weatherParams.r * mixedCloudDensity;

    //添加细节
    if (cloudDensity > 0 && sampleDetail)
    {
        //细节噪声受更强风的影响，添加稍微向上的偏移
        position += (sif.windDir + float3(0, 0.1, 0)) * sif.windSpeed * _Time.y * 0.1;
        float3 detailTex = SAMPLE_TEXTURE3D_LOD(_CloudDetailTex, sampler_CloudDetailTex, position * 0.0001, 0).rgb;
        float detailTexFBM = dot(detailTex, float3(0.5, 0.25, 0.125));

        //根据高度从纤细到波纹的形状进行变化
        float detailNoise = detailTexFBM; //lerp(detailTexFBM, 1.0 - detailTexFBM,saturate(heightFraction * 1.0));
        //通过使用remap映射细节噪声，可以保留基本形状，在边缘进行变化
        cloudDensity = Remap(cloudDensity, detailNoise * sif.detailIntensity, 1.0, 0.0, 1.0);
    }

    o.density = cloudDensity * sif.densityScale * 0.01;
    o.absorptivity = cloudAbsorption;
    return o;
}

//-------------------------------------------------------云光照计算帮助函数---------------------------------------------------------
//Beer衰减
float Beer(float density, float absorptivity = 1)
{
    return exp(-density * absorptivity);
}

//粉糖效应，模拟云的内散射影响
float BeerPowder(float density, float absorptivity = 1)
{
    return 2.0 * exp(-density * absorptivity) * (1.0 - exp(-2.0 * density));
}

//Henyey-Greenstein相位函数
float HenyeyGreenstein(float angle, float g)
{
    float g2 = g * g;
    return (1.0 - g2) / (4.0 * PI * pow(1.0 + g2 - 2.0 * g * angle, 1.5));
}

//两层Henyey-Greenstein散射，使用Max混合。同时兼顾向前 向后散射
float HGScatterMax(float angle, float g_1, float intensity_1, float g_2, float intensity_2)
{
    return max(intensity_1 * HenyeyGreenstein(angle, g_1), intensity_2 * HenyeyGreenstein(angle, g_2));
}

//两层Henyey-Greenstein散射，使用Lerp混合。同时兼顾向前 向后散射
float HGScatterLerp(float angle, float g_1, float g_2, float weight)
{
    return lerp(HenyeyGreenstein(angle, g_1), HenyeyGreenstein(angle, g_2), weight);
}

// //获取光照亮度
// float GetLightEnergy(float density, float absorptivity, float darknessThreshold)
// {
//     float energy = BeerPowder(density, absorptivity);
//     return darknessThreshold + (1.0 - darknessThreshold) * energy;
// }
