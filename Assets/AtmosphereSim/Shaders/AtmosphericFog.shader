// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "Custom/AtmosphericFog"
{
    Properties {}

    SubShader
    {
        LOD 0


        Tags
        {
            "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
        #include "AtmosphericScatteringCommon.hlsl"
        #pragma target 3.0
        ENDHLSL


        Pass
        {
            //            ZTest Always 
            //            Cull Off 
            //            ZWrite Off

            HLSLPROGRAM
            #pragma vertex vertDir
            #pragma fragment fragDir
            #pragma target 4.0

            #pragma multi_compile _ _LIGHTSHAFT_ON
            #pragma multi_compile _ _EXTINCTION_ON
            #pragma multi_compile _ _INSCATTERING_ON

            #define UNITY_HDR_ON
            
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);
            uniform float4 _FrustumCorners[4];
            uniform float3 _SunLightDir;

            struct VSInput
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                uint vertexId : SV_VertexID;
            };

            struct PSInput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 wpos : TEXCOORD1;
            };

            PSInput vertDir(VSInput i)
            {
                PSInput o;

                o.pos = TransformObjectToHClip(i.vertex);
                o.uv = i.uv;
                o.wpos = _FrustumCorners[i.vertexId];

                return o;
            }

            float3 fragDir(PSInput i) : COLOR0
            {
                float2 uv = i.uv.xy;
                float linearDepth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uv), _ZBufferParams);

                float3 wpos = i.wpos;
                float3 rayStart = _WorldSpaceCameraPos;
                float3 rayDir = wpos - _WorldSpaceCameraPos;
                rayDir *= linearDepth;

                float rayLength = length(rayDir);
                rayDir /= rayLength;

                float3 planetCenter = _WorldSpaceCameraPos;
                planetCenter = float3(0, -_PlanetRadius, 0);
                float2 intersection = RaySphereIntersection(rayStart, rayDir, planetCenter, _PlanetRadius + _AtmosphereHeight);
                if (linearDepth > 0.99999)
                {
                    rayLength = 1e20;
                }
                rayLength = min(intersection.y, rayLength);

                intersection = RaySphereIntersection(rayStart, rayDir, planetCenter, _PlanetRadius);
                if (intersection.x > 0)
                    rayLength = min(rayLength, intersection.x);

                float3 extinction;
                _SunRenderIntensity = 0;
                float3 inscattering = IntegrateInscattering(rayStart, rayDir, rayLength, planetCenter, _DistanceScale, _SunLightDir, 64, extinction);
                inscattering *= _SunRenderColor.xyz;

                // LIGHT_SHAFTS
                float shadow = SAMPLE_TEXTURE2D(_LightShaft,sampler_LightShaft, uv.xy).x;
                shadow = (pow(shadow, 4) + shadow) / 2;
                shadow = max(0.1, shadow);
                #if defined(_LIGHTSHAFT_ON)
                inscattering *= shadow;
                #endif
                
                float3 background = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, uv);

                if (linearDepth > 0.99999)
                {
                    #if defined(_LIGHTSHAFT_ON)
                    background *= shadow;
                    #endif
                    inscattering = 0;
                    extinction = 1;
                }

                float3 c = background * extinction + inscattering;
                // return float3(shadow,shadow,shadow);
                // return inscattering;
                #if defined(_EXTINCTION_ON)
                return extinction;
                #endif
                #if defined(_INSCATTERING_ON)
                return inscattering;
                #endif
                return c;
            }
            ENDHLSL
        }

    }
    Fallback "Hidden/InternalErrorShader"

}