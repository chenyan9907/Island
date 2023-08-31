Shader "Custom/FFTOcean"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _SSSColor("SSS Color", Color) = (1,1,1,1)
        _SSSStrength("SSSStrength", Range(0,1)) = 0.2
        _SSSScale("SSS Scale", Range(0.1,50)) = 4.0
        _SSSBase("SSS Base", Range(-5,1)) = 0
        _LOD_scale("LOD_scale", Range(1,10)) = 0
        _MaxGloss("Max Gloss", Range(0,1)) = 0
        _Roughness("Roughness", Range(0.01,1)) = 0
        _RoughnessScale("Roughness Scale", Range(0, 0.01)) = 0.1
        _FoamColor("Foam Color", Color) = (1,1,1,1)
        _FoamTexture("Foam Texture", 2D) = "grey" {}
        _FoamBiasLOD0("Foam Bias LOD0", Range(0,7)) = 1
        _FoamBiasLOD1("Foam Bias LOD1", Range(0,7)) = 1
        _FoamBiasLOD2("Foam Bias LOD2", Range(0,7)) = 1
        _FoamScale("Foam Scale", Range(0,20)) = 1
        _ContactFoam("Contact Foam", Range(0,1)) = 1
        _SpecularIntensity("_SpecularIntensity",Range(0,1)) = 0.3
        [Toggle]_BlinnPhongSpecular("Enable BlinnPhong Specular", Int) = 0
        _Shininess("Shininess",Float) = 20
        _RefractIntensity("Refract Intensity",Range(0,1)) = 0.05
        [Toggle]_EnvLight("Enable Environment Light", Int) = 1
        _var("var",float) = 25


        [Header(Cascade 0)]
        [Space(10)]
        _Displacement_c0("Displacement C0", 2D) = "black" {}
        _Derivatives_c0("Derivatives C0", 2D) = "black" {}
        _Turbulence_c0("Turbulence C0", 2D) = "white" {}
        [Header(Cascade 1)]
        [Space(10)]
        _Displacement_c1("Displacement C1", 2D) = "black" {}
        _Derivatives_c1("Derivatives C1", 2D) = "black" {}
        _Turbulence_c1("Turbulence C1", 2D) = "white" {}
        [Header(Cascade 2)]
        [Space(10)]
        _Displacement_c2("Displacement C2", 2D) = "black" {}
        _Derivatives_c2("Derivatives C2", 2D) = "black" {}
        _Turbulence_c2("Turbulence C2", 2D) = "white" {}
    }
    SubShader
    {
        Tags
        {
            // 注意 Debug面板中设置为-1
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }
        LOD 200

        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            //在OpenGL ES2.0中使用HLSLcc编译器,目前除了OpenGL ES2.0全都默认使用HLSLcc编译器.
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0
            #pragma multi_compile_instancing
            #pragma multi_compile _ MID CLOSE
            #pragma multi_compile _ _BLINNPHONGSPECULAR_ON
            #pragma multi_compile _ _ENVLIGHT_ON
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOW_SOFT        //开启软阴影

            // Includes
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.shadergraph/ShaderGraphLibrary/ShaderVariablesFunctions.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float4 _SSSColor;
                float _SSSStrength;
                float _SSSScale;
                float _SSSBase;
                float _LOD_scale;
                float LengthScale0;
                float LengthScale1;
                float LengthScale2;
                float _MaxGloss;
                float _Roughness;
                float _RoughnessScale;
                float4 _FoamColor;
                float _FoamBiasLOD0;
                float _FoamBiasLOD1;
                float _FoamBiasLOD2;
                float _FoamScale;
                float _ContactFoam;
                float _SpecularIntensity;
                float _Shininess;
                float _RefractIntensity;
                float _var;
            CBUFFER_END

            TEXTURE2D(_FoamTexture);
            SAMPLER(sampler_FoamTexture);
            TEXTURE2D(_Displacement_c0);
            SAMPLER(sampler_Displacement_c0);
            TEXTURE2D(_Derivatives_c0);
            SAMPLER(sampler_Derivatives_c0);
            TEXTURE2D(_Turbulence_c0);
            SAMPLER(sampler_Turbulence_c0);
            TEXTURE2D(_Displacement_c1);
            SAMPLER(sampler_Displacement_c1);
            TEXTURE2D(_Derivatives_c1);
            SAMPLER(sampler_Derivatives_c1);
            TEXTURE2D(_Turbulence_c1);
            SAMPLER(sampler_Turbulence_c1);
            TEXTURE2D(_Displacement_c2);
            SAMPLER(sampler_Displacement_c2);
            TEXTURE2D(_Derivatives_c2);
            SAMPLER(sampler_Derivatives_c2);
            TEXTURE2D(_Turbulence_c2);
            SAMPLER(sampler_Turbulence_c2);
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);


            // 顶点着色器的输入
            struct vertInput
            {
                float3 positionOS : POSITION;
                float2 uv :TEXCOORD0;
            };

            // 顶点着色器的输出
            struct vertOutput
            {
                float4 positionCS : SV_POSITION;
                float2 uv :TEXCOORD0;
                float2 worldUV : TEXCOORD1;
                float4 lodScales : TEXCOORD2;
                float3 positionWS : TEXCOORD3;
                float4 positionSS : TEXCOORD4;
            };


            // 顶点着色器
            vertOutput vert(vertInput v)
            {
                vertOutput o = (vertOutput)0;
                VertexPositionInputs vertexPositionInputs = GetVertexPositionInputs(v.positionOS);
                // o.positionCS = vertexPositionInputs.positionCS;
                float3 positionWS = vertexPositionInputs.positionWS;
                o.positionWS = positionWS;
                o.worldUV = positionWS.xz;
                o.uv = v.uv;
                float3 viewDirWS = GetCameraPositionWS() - positionWS;
                float viewDist = length(viewDirWS);

                float lod_c0 = min(_LOD_scale * LengthScale0 / viewDist, 1);
                float lod_c1 = min(_LOD_scale * LengthScale1 / viewDist, 1);
                float lod_c2 = min(_LOD_scale * LengthScale2 / viewDist, 1);

                float3 displacement = 0;
                float largeWavesBias = 0;

                displacement += SAMPLE_TEXTURE2D_LOD(_Displacement_c0, sampler_Displacement_c0, o.worldUV/LengthScale0, 0) * lod_c0;
                largeWavesBias = displacement.y;
                #if defined(MID) || defined(CLOSE)
                displacement += SAMPLE_TEXTURE2D_LOD(_Displacement_c1,sampler_Displacement_c1,o.worldUV/LengthScale1,0)*lod_c1;
                #endif
                #if defined(CLOSE)
                displacement += SAMPLE_TEXTURE2D_LOD(_Displacement_c2,sampler_Displacement_c2,o.worldUV/LengthScale2,0)*lod_c2;
                #endif
                positionWS += displacement;
                o.positionCS = TransformObjectToHClip(TransformWorldToObject(positionWS));
                o.positionSS = ComputeScreenPos(o.positionCS);

                o.lodScales = float4(lod_c0, lod_c1, lod_c2, max(displacement.y - largeWavesBias * 0.8 - _SSSBase, 0) / _SSSScale);

                return o;
            }

            float NormalDistributionFunc_GGX(float NdotH, float roughness)
            {
                //迪士尼原则中的 a
                float a = roughness * roughness;
                float a2 = a * a;
                float NdotH2 = NdotH * NdotH;
                float num = a2;
                float denom = NdotH2 * (a2 - 1.0) + 1.0;
                denom = PI * denom * denom;
                return num / denom;
            }

            float3 Fresnel_Schlick(float VdotH, float3 F0)
            {
                return F0 + (1 - F0) * pow(1 - VdotH, 5);
            }

            //G项，几何函数：描述微平面自遮挡比例，同时考虑视线和光线方向的自遮挡，受粗糙度影响
            float GeometryFunc_SchlickGGX(float NdotV, float NdotL, float roughness)
            {
                float a = roughness * roughness;
                float r = a + 1.0;
                float k = (r * r) / 8.0;
                float GV = NdotV / (NdotV * (1.0 - k) + k); //视线方向
                float GL = NdotL / (NdotL * (1.0 - k) + k); //光线方向
                return GV * GL;
            }

            float pow5(float f)
            {
                return f * f * f * f * f;
            }

            // 片段着色器
            half4 frag(vertOutput i) : SV_TARGET
            {
                float4 derivatives = SAMPLE_TEXTURE2D(_Derivatives_c0, sampler_Derivatives_c0, i.worldUV/LengthScale0);
                #if defined(MID) || defined(CLOSE)
                derivatives += SAMPLE_TEXTURE2D(_Derivatives_c1,sampler_Derivatives_c1,i.worldUV/LengthScale1)*i.lodScales.y;
                #endif
                #if defined(CLOSE)
                derivatives += SAMPLE_TEXTURE2D(_Derivatives_c2,sampler_Derivatives_c2,i.worldUV/LengthScale2)*i.lodScales.z;
                #endif
                float2 slope = float2(derivatives.x / (1 + derivatives.z), derivatives.y / (1 + derivatives.w));
                float3 normalWS = normalize(float3(-slope.x, 1, -slope.y));

                #if defined(CLOSE)
                float jacobian = SAMPLE_TEXTURE2D(_Turbulence_c0,sampler_Turbulence_c0, i.worldUV / LengthScale0).x
                + SAMPLE_TEXTURE2D(_Turbulence_c1,sampler_Turbulence_c1, i.worldUV / LengthScale1).x
                + SAMPLE_TEXTURE2D(_Turbulence_c2,sampler_Turbulence_c2, i.worldUV / LengthScale2).x;
                jacobian = min(1, max(0, (-jacobian + _FoamBiasLOD2) * _FoamScale));
                #elif defined(MID)
                float jacobian = SAMPLE_TEXTURE2D(_Turbulence_c0,sampler_Turbulence_c0, i.worldUV / LengthScale0).x
                + SAMPLE_TEXTURE2D(_Turbulence_c1,sampler_Turbulence_c1, i.worldUV / LengthScale1).x;
                jacobian = min(1, max(0, (-jacobian + _FoamBiasLOD1) * _FoamScale));
                #else
                float jacobian = SAMPLE_TEXTURE2D(_Turbulence_c0, sampler_Turbulence_c0, i.worldUV / LengthScale0).x;
                jacobian = min(1, max(0, (-jacobian + _FoamBiasLOD0) * _FoamScale));
                #endif

                // 海中遮挡物的边缘白沫
                float2 screenUV = GetNormalizedScreenSpaceUV(i.positionCS);
                float eyeDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV), _ZBufferParams);
                // 把不同平台下的裁剪空间下的z值映射到[0, far]的范围
                float surfaceDepth = UNITY_Z_0_FAR_FROM_CLIPSPACE(i.positionCS.z);
                float depthDiff = max(0, eyeDepth - surfaceDepth - 0.1);
                float foam = SAMPLE_TEXTURE2D(_FoamTexture, sampler_FoamTexture, i.worldUV * 0.5 + _Time.x).r;
                // jacobian += _ContactFoam * saturate(max(0, foam - depthDiff) * 5) * 0.9;

                Light mainLight = GetMainLight(TransformWorldToShadowCoord(i.positionWS));
                float lightIntensity = clamp(length(mainLight.color),0.05,1);
                float3 lightDirWS = normalize(mainLight.direction);
                float3 viewDirWS = normalize(_WorldSpaceCameraPos - i.positionWS);
                float3 halfDirWS = normalize(lightDirWS + viewDirWS);

                float VdotH = saturate(dot(viewDirWS, halfDirWS));
                float NdotH = saturate(dot(normalWS, halfDirWS));
                float LdotH = saturate(dot(lightDirWS, halfDirWS));
                float NdotV = saturate(dot(normalWS, viewDirWS));
                float NdotL = saturate(dot(normalWS, lightDirWS));

                // 结合地平线眺望和雅可比波峰的高光项
                float distanceGloss = lerp(1 - _Roughness, _MaxGloss, 1 / (1 + length(_WorldSpaceCameraPos - i.positionWS) * _RoughnessScale));
                float roughness = 1 - lerp(distanceGloss, 0, jacobian);
                float3 ks = Fresnel_Schlick(VdotH, float3(0.04, 0.04, 0.04));
                // float a = _Roughness * _Roughness;
                float a = roughness * roughness;
                float a2 = a * a;
                float D = (1.0 / (PI * a2)) * pow(NdotH, 2 / a2 - 2);
                float FV = 0.25 * pow(LdotH, -3);
                float3 PBRspecular = ks * D * FV;
                PBRspecular *= mainLight.color * mainLight.shadowAttenuation * _SpecularIntensity;

                //传统PBR高光项
                float dTerm = NormalDistributionFunc_GGX(NdotH, _Roughness);
                float3 fTerm = Fresnel_Schlick(VdotH, float3(0.04, 0.04, 0.04));
                float gTerm = GeometryFunc_SchlickGGX(NdotV, NdotL, _Roughness);
                float3 directBRDFSpecFactor = dTerm * fTerm * gTerm / (4.0 * NdotV * NdotL);

                //计算SSS颜色（光线穿过波峰）
                float3 halfNL = normalize(-normalWS + lightDirWS);
                float ViewDotH = pow5(saturate(dot(viewDirWS, -halfNL))) * 30 * _SSSStrength;
                half3 color = lerp(_Color, saturate(_Color + _SSSColor.rgb * ViewDotH * i.lodScales.w), i.lodScales.z) * mainLight.shadowAttenuation;

                //BlinnPhong反射
                #if defined(_BLINNPHONGSPECULAR_ON)
                PBRspecular = pow(max(NdotH, 0), _Shininess);
                #endif

                float3 foamColor = lerp(0, _FoamColor, jacobian);

                float3 reflectDir = normalize(reflect(-lightDirWS, normalWS));
                half4 envCol = SAMPLE_TEXTURECUBE(unity_SpecCube0, samplerunity_SpecCube0, reflectDir);
                half3 envHDRCol = DecodeHDREnvironment(envCol, unity_SpecCube0_HDR);

                // 在renderer data中设置depth为after opaque
                 // float existingDepthLinear = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.positionSS.xy/i.positionSS.w), _ZBufferParams);
                 // float eyeDepth1 = LinearEyeDepth(i.positionCS.z, _ZBufferParams);
                 // float depthDifference = existingDepthLinear - eyeDepth1;

                float2 refractionUV = screenUV + normalWS.xz * _RefractIntensity;
                half3 refraction = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, refractionUV);
                lightIntensity = clamp(lightIntensity*0.1,0.05,1);
                

                // return half4(refraction, 1);
                // return half4(i.positionSS.xy/i.positionSS.w,0, 1);
                // return half4(envHDRCol, 1);
                #if defined(_ENVLIGHT_ON)
                // return half4(color,1);
                return half4(color + PBRspecular + (foamColor + envHDRCol)*lightIntensity + refraction, 1);
                #endif
                return half4(color + PBRspecular + (foamColor)*lightIntensity + refraction, 1);
                // return half4(color + PBRspecular + (foamColor + envHDRCol)*lightIntensity + refraction, 1);
                // return half4(float2(positionSS.xy/positionSS.w), 0, 1);
                // return half4(screenUV, 0, 1);
                // return half4(depthDifference, depthDifference, depthDifference, 1);
                return half4(mainLight.shadowAttenuation, mainLight.shadowAttenuation, mainLight.shadowAttenuation, 1);
                return half4(jacobian, jacobian, jacobian, 1);
                return half4(normalWS, 1);
                return _Color;
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/Shader Graph/FallbackError"
}