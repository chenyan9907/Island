Shader "Custom/AtmosphericScatteringLUT"
{
    Properties
    {
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Opaque"
        }

        HLSLINCLUDE
        // Includes
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
        #include "Packages/com.unity.shadergraph/ShaderGraphLibrary/ShaderVariablesFunctions.hlsl"
        #include "AtmosphericScatteringCommon.hlsl"

        // CBUFFER_START(UnityPerMaterial)
        // // float4 _MainTex_ST;
        // CBUFFER_END

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
        };
        ENDHLSL

        Pass
        {
            //Pass 0 预计算大气密度
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #define UNITY_HDR_ON

            // 顶点着色器
            vertOutput vert(vertInput v)
            {
                vertOutput o = (vertOutput)0;
                o.uv = v.uv;
                VertexPositionInputs vertexPositionInputs = GetVertexPositionInputs(v.positionOS);
                o.positionCS = vertexPositionInputs.positionCS;
                o.positionWS = vertexPositionInputs.positionWS;
                return o;
            }

            // 片段着色器
            float2 frag(vertOutput i) : SV_TARGET
            {
                //大气密度LUT，横坐标为太阳入射角，纵坐标为当前距地表的高度
                //rayDir为xOy平面上的圆，因为大气的对称性，可以忽略y轴旋转，故此圆可以视为绕y轴一周形成一个球体
                //计算基于以球心为原点的坐标系
                float cosAngle = i.uv.x * 2.0 - 1.0;
                float sinAngle = sqrt(1 - cosAngle * cosAngle);
                float startHeight = lerp(0.0, _AtmosphereHeight, i.uv.y);

                float3 rayStart = float3(0, startHeight, 0);
                float3 rayDir = float3(sinAngle, cosAngle, 0);
                // rayDir = float3(0, cosAngle, sinAngle);
                return PrecomputeAtmosphereDensityToTop(rayStart, rayDir);
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/Shader Graph/FallbackError"
}