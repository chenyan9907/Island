// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "Custom/Cloud"
{
    Properties
    {
        [Header(Cloud Shape Settings)]
        [Space(10)]
        _EarthRadius("地球半径",Float) = 6371000
        _CloudHeightMinMax("云层高度范围",Vector) = (1500,4000,0,0)
        [NoScaleOffset]_WeatherTex("天气纹理",2D) = "white"{}
        _WeatherTexTiling("天气纹理平铺",Float) = 10
        [NoScaleOffset]_CloudBaseTex("云层基础纹理",3D) = "white"{}
        [NoScaleOffset]_CloudDetailTex("云层细节纹理",3D) = "white"{}
        _DetailIntensity ("细节影响强度", Range(0, 1)) = 1
        _StratusRange ("层云范围", vector) = (0.1, 0.4, 0, 0)
        _StratusFeather ("层云边缘羽化", Range(0, 1)) = 0.2
        _CumulusRange ("积云范围", vector) = (0.15, 0.8, 0, 0)
        _CumulusFeather ("积云边缘羽化", Range(0, 1)) = 0.2
        _CloudCoverage ("云层覆盖率",Range(0,1)) = 0.5
        _DensityScale ("云层密度规模",Range(0,2)) = 0.7

        [Header(Cloud Lighting Settings)]
        [Space(10)]
        _CloudAbsorb ("云层吸收率", Range(0, 4)) = 0.7
        _ScatterForward("向前散射",Range(0,0.99)) = 0.5
        _ScatterForwardIntensity("向前散射强度",Range(0,1)) = 1
        _ScatterBackward("向后散射",Range(0,0.99)) = 0.4
        _ScatterBackwardIntensity("向后散射强度",Range(0,1)) = 0.4
        _ScatterBase("基础散射",Range(0,0.99)) = 0.2
        _ScatterMultiply("散射相位乘数",Range(0,1)) = 0.7
        [HDR] _ColorDark("暗部颜色",Color) = (0.2,0.2,0.2,1)
        [HDR] _ColorMiddle("中间颜色",Color) = (0.5,0.5,0.5,1)
        [HDR] _ColorBright("亮部颜色",Color) = (0.95,0.95,0.95,1)
        _DarknessThreshold("暗部阈值",Range(0,1)) = 0.15
        _MiddleColorOffset("中间颜色偏移",Range(0,1)) = 0.5

        [Header(Environment Settings)]
        [Space(10)]
        _WindDir("风向",Vector) = (1,0,0,0)
        _WindSpeed("风速",Range(0,5)) = 1

        [Header(RayMarch)]
        [Space(10)]
        _MarchLength("单次基础步进长度（形状）",Float) = 300
        _MarchMaxCount("最大步进次数（形状）",Float) = 30
        _MarchMaxCountLight("最大步进次数（光照）",Float) = 8
        _BlueNoiseEffect("蓝噪声影响程度",Range(0,1)) = 1

        [HideInInspector]_MainTex ("Texture", 2D) = "white" { }
    }
    SubShader
    {
        LOD 0


        Tags
        {
            "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "CloudCommon.hlsl"
        #pragma target 3.0
        ENDHLSL

        Pass
        {
            //            ZTest Always 
            //            Cull Off 
            //            ZWrite Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 4.0

            #define UNITY_HDR_ON

            CBUFFER_START(UnityPerMaterial)
                float _EarthRadius;
                float4 _CloudHeightMinMax;
                float _WeatherTexTiling;
                float _DetailIntensity;
                float2 _StratusRange;
                float _StratusFeather;
                float2 _CumulusRange;
                float _CumulusFeather;
                float _CloudCoverage;
                float _DensityScale;

                float _CloudAbsorb;
                float _ScatterForward;
                float _ScatterForwardIntensity;
                float _ScatterBackward;
                float _ScatterBackwardIntensity;
                float _ScatterBase;
                float _ScatterMultiply;
                float4 _ColorDark;
                float4 _ColorMiddle;
                float4 _ColorBright;
                float _DarknessThreshold;
                float _MiddleColorOffset;

                float3 _WindDir;
                float _WindSpeed;

                float _MarchLength;
                float _MarchMaxCount;
                float _MarchMaxCountLight;
                float _BlueNoiseEffect;

                float2 _BlueNoiseTexUV;

            CBUFFER_END

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);
            TEXTURE2D(_BlueNoiseTex);
            SAMPLER(sampler_BlueNoiseTex);

            struct VertInput
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct VertOutput
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 viewDir : TEXCOORD1;
            };

            VertOutput vert(VertInput v)
            {
                VertOutput o;

                VertexPositionInputs vertexPositionInputs = GetVertexPositionInputs(v.positionOS);
                o.positionCS = vertexPositionInputs.positionCS;
                o.uv = v.uv;
                float3 viewDir = mul(unity_CameraInvProjection, float4(v.uv * 2.0 - 1.0, 0, -1)).xyz;
                o.viewDir = mul(unity_CameraToWorld, float4(viewDir, 0)).xyz;

                return o;
            }

            half4 frag(VertOutput i) : COLOR0
            {
                float dstToObj = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv), _ZBufferParams);

                Light mainLight = GetMainLight();
                float3 viewDir = normalize(i.viewDir);
                float3 lightDir = normalize(mainLight.direction);
                float3 cameraPos = _WorldSpaceCameraPos;

                float3 planetCenter = float3(0, -_EarthRadius, 0);
                float2 rayInCloud = RayCloudDst(planetCenter, _EarthRadius, _CloudHeightMinMax.x, _CloudHeightMinMax.y, cameraPos, viewDir);
                float dstToCloud = rayInCloud.x;
                float dstInCloud = rayInCloud.y;

                //被遮挡或不在云层layer时
                if (dstInCloud <= 0 || dstToObj <= dstToCloud)
                {
                    return half4(0, 0, 0, 1);
                }

                SampleInfo sif;
                sif.earthRadius = _EarthRadius;
                sif.cloudHeightMinMax = _CloudHeightMinMax;
                sif.weatherTexTiling = _WeatherTexTiling;
                sif.detailIntensity = _DetailIntensity;
                sif.cloudCoverage = _CloudCoverage;
                sif.stratusParams = float3(_StratusRange, _StratusFeather);
                sif.cumulusParams = float3(_CumulusRange, _CumulusFeather);
                sif.densityScale = _DensityScale;

                sif.cloudAbsorb = _CloudAbsorb;

                sif.windDir = _WindDir;
                sif.windSpeed = _WindSpeed;

                //向前&向后散射
                float phase = HGScatterMax(dot(viewDir, lightDir), _ScatterForward, _ScatterForwardIntensity, _ScatterBackward, _ScatterBackwardIntensity);
                phase = _ScatterBase + phase * _ScatterMultiply;

                //采样BlueNoise，用来偏移步进起始点，消除步进结果层次感
                float blueNoise = SAMPLE_TEXTURE2D(_BlueNoiseTex, sampler_BlueNoiseTex, i.uv*_BlueNoiseTexUV).r;

                //步进结束距离
                float endLength = dstToCloud + dstInCloud;
                //步进长度，受蓝噪声影响，步进长度略有不同，首次步进加上到云层的距离
                float currentMarchLength = dstToCloud + _MarchLength * blueNoise * _BlueNoiseEffect;
                float3 currentPos = cameraPos + viewDir * currentMarchLength;

                float totalDensity = 0;
                float3 totalLum = 0;
                float lightAtten = 1.0;

                float currentDensity = 0;
                float prevDensity = 0;
                //记录连续为0密度的次数，从而快速退出结束循环
                float zeroDensityCount = 0;

                //开始步进
                for (int marchCount = 0; marchCount < _MarchMaxCount; marchCount++)
                {
                    if (currentDensity == 0)
                    {
                        //以两倍步长快速接近云层
                        currentMarchLength += _MarchLength * 2.0;
                        currentPos = cameraPos + viewDir * currentMarchLength;

                        //若有物体遮挡或者到达结束距离
                        if (dstToObj <= currentMarchLength || endLength <= currentMarchLength)
                        {
                            break;
                        }

                        sif.position = currentPos;
                        currentDensity = SampleCloudDensity(sif, false).density;

                        //当检测到步进长度
                        if (currentDensity > 0)
                        {
                            currentMarchLength -= _MarchLength;
                        }
                    }
                    else // 当前点位密度不为零，开始累计密度
                    {
                        currentPos = cameraPos + viewDir * currentMarchLength;
                        sif.position = currentPos;
                        CloudParams cloudParams = SampleCloudDensity(sif, true);

                        //如果连续两次采样点密度为0，则计入连续0密度计数
                        if (cloudParams.density == 0 && prevDensity == 0)
                        {
                            zeroDensityCount += 1;
                            if (zeroDensityCount >= 8)
                            {
                                currentDensity = 0;
                                zeroDensityCount = 0;
                                continue;
                            }
                        }
                        float density = cloudParams.density * _MarchLength;

                        float currentLum = 0;
                        //计算光照
                        if (density > 0.01)
                        {
                            float2 dstLightInCloud = RayCloudDst(planetCenter, _EarthRadius, _CloudHeightMinMax.x, _CloudHeightMinMax.y, currentPos, lightDir, true);
                            float marchLengthLight = dstLightInCloud.y / _MarchMaxCountLight;
                            float3 currentPosLight = currentPos;
                            float totalDensityLight = 0;

                            for (int marchCountLight = 0; marchCountLight < _MarchMaxCountLight; marchCountLight++)
                            {
                                currentPosLight += lightDir * marchLengthLight;
                                sif.position = currentPosLight;
                                float densityLight = SampleCloudDensity(sif).density * marchLengthLight;
                                totalDensityLight += densityLight;
                            }
                            currentLum = BeerPowder(totalDensityLight, cloudParams.absorptivity);

                            currentLum = _DarknessThreshold + currentLum * (1.0 - _DarknessThreshold);
                            //云层颜色
                            float3 cloudColor = Interpolation3(_ColorDark.rgb, _ColorMiddle.rgb, _ColorBright.rgb, saturate(currentLum), _MiddleColorOffset) * mainLight.color;

                            totalLum += lightAtten * cloudColor * density * phase;
                            totalDensity += density;
                            lightAtten *= Beer(density, cloudParams.absorptivity);

                            if (lightAtten < 0.01)
                            {
                                break;
                            }
                        }

                        currentMarchLength += _MarchLength;

                        if (dstToObj <= currentMarchLength || endLength <= currentMarchLength)
                        {
                            break;
                        }
                        prevDensity = cloudParams.density;
                    }
                }


                // return half4(_BlueNoiseTexUV, 0, 1);
                // return half4(currentDensity, currentDensity, currentDensity, 1);
                return half4(totalLum, lightAtten);
                return half4(blueNoise, blueNoise, blueNoise, 1);
                return half4(i.viewDir, 0.5);
            }
            ENDHLSL
        }

        pass
        {
            //最后的颜色应当为backColor.rgb * lightAttenuation + totalLum, 但是因为分帧渲染，混合需要特殊处理
            //云的返回颜色为half4(totalLum, lightAttenuation) , 将此混合设置为Blend One SrcAlpha 最后的颜色将为totalLum + lightAttenuation * baseColor
            //
            // 此处MainTex默认为上一个pass的结果，Dst为正常相机颜色缓冲
            // Blend命令表示：当前Pass的颜色RGB（云层着色结果） * 1 + 相机颜色缓冲 * 当前Pass的Alpha（云层光照衰减）
            // 光照衰减越大，云层越淡
            Blend One SrcAlpha
//            Blend One Zero

            HLSLPROGRAM
            #pragma vertex vert_blend
            #pragma fragment frag_blend

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            struct appdata
            {
                float4 vertex: POSITION;
                float2 uv: TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex: SV_POSITION;
                float2 uv: TEXCOORD0;
            };

            v2f vert_blend(appdata v)
            {
                v2f o;

                VertexPositionInputs vertexPos = GetVertexPositionInputs(v.vertex.xyz);
                o.vertex = vertexPos.positionCS;
                o.uv = v.uv;
                return o;
            }

            half4 frag_blend(v2f i): SV_Target
            {
                return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
            }
            ENDHLSL
        }

    }
    Fallback "Hidden/InternalErrorShader"

}