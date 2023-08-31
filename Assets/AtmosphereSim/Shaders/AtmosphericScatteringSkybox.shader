Shader "Custom/AtmosphericScatteringSkybox"
{
    Properties
    {
//        _AtmosphereHeight("行星大气高度", Float) = 80000
//        _PlanetRadius("行星半径",Float) = 6371000
//        _DensityScalarHeight("大气密度标高（瑞利散射，米氏散射）", Vector) = (7994,1200,0,0)
//        _RayleighSct("瑞利散射Beta",Vector) = (0.0000058, 0.0000135, 0.0000331, 0.0)
//        _RayleighSctIntensity("瑞利散射强度",Range(0,1)) = 1
//        _MieSct("米氏散射Beta",Vector) = (0.0000039,0.0000039,0.0000039,0)
//        _MieSctIntensity("米氏散射强度",Range(0,1)) = 1
//        _MieG("米氏散射G",Range(-1,1)) = 0.76
//        [HDR] _IncomingLight("光源设置",Color) = (4,4,4,1)
//        _SunIntensity("太阳强度",Float) = 1
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Background"
            "Queue"="Background"
            "PreviewType" = "Skybox"
        }

        Cull Off
        ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0
            #pragma multi_compile_instancing

            // Includes
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.shadergraph/ShaderGraphLibrary/ShaderVariablesFunctions.hlsl"
            #include "AtmosphericScatteringCommon.hlsl"

            CBUFFER_START(UnityPerMaterial)
            // float4 _MainTex_ST;
            CBUFFER_END
            

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
                float3 positionWS : TEXCOORD1;
                float3 positionOS : TEXCOORD2;
            };


            // 顶点着色器
            vertOutput vert(vertInput v)
            {
                vertOutput o = (vertOutput)0;
                o.uv = v.uv;
                VertexPositionInputs vertexPositionInputs = GetVertexPositionInputs(v.positionOS);
                o.positionCS = vertexPositionInputs.positionCS;
                o.positionWS = vertexPositionInputs.positionWS;
                o.positionOS = v.positionOS;
                return o;
            }

            // 片段着色器
            half4 frag(vertOutput i) : SV_TARGET
            {
                //根据当前场景设定高度，调整摄像机高度值
                float3 rayPos = _WorldSpaceCameraPos;
                rayPos += float3(0,_CurrentSceneHeight,0);
                // 天空盒一般是随着相机移动的，相机相对于天空而言是静止的，因此此处不需要i.positionWS - eyePos
                // 相机就处于行星轴线上
                float3 rayDir = normalize(i.positionWS);
                // rayDir = normalize(TransformObjectToWorld(i.positionOS));
                float3 lightDir = _MainLightPosition.xyz;    // ==mainLight.direction
                float3 planetCenter = float3(0, -_PlanetRadius, 0);
                float2 intersection = RaySphereIntersection(rayPos, rayDir, planetCenter, _PlanetRadius + _AtmosphereHeight);
                float rayLength = intersection.y; //（相机在大气层内，必有两解）取二元一次方程组两个解中正的那个，即视线正方向与大气层相交的点。（intersection.x在视线负方向与大气层相交）

                intersection = RaySphereIntersection(rayPos, rayDir, planetCenter, _PlanetRadius); //与地表求交
                if (intersection.x >= 0)
                {
                    //与地表求交，判断上面测得的eyeLength是否为穿过地表取到了地表后面的大气层交点
                    //若intersection.x>=0，则表示该视线与地表有交点，取近的那个点作为eyeLength
                    rayLength = min(rayLength, intersection.x);
                }

                float3 extinction;
                float3 inscattering = IntegrateInscattering(rayPos, rayDir, rayLength, planetCenter, 1, lightDir, 64,extinction);
                
                // return half4(extinction,1);
                float4 lightShaft = SAMPLE_TEXTURE2D(_LightShaft,sampler_LightShaft,i.uv);
                return half4(inscattering,1);
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/Shader Graph/FallbackError"
}