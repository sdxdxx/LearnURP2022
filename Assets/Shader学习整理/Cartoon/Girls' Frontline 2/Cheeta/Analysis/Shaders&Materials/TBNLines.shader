Shader "Debug/URP_GeometryTBNLines"
{
    Properties
    {
        [Header(TBN Toggles)]
        [Toggle] _ShowNormal ("Show Normal (法线)", Float) = 1.0
        [Toggle] _ShowTangent ("Show Tangent (切线)", Float) = 1.0
        [Toggle] _ShowBitangent ("Show Bitangent (副切线)", Float) = 1.0

        [Space(10)]
        [Header(Line Settings)]
        _VectorLength ("Vector Length (线条长度)", Range(0.01, 2.0)) = 0.1
        _NormalColor ("Normal Color", Color) = (0, 0, 1, 1)      // 默认蓝色
        _TangentColor ("Tangent Color", Color) = (1, 0, 0, 1)    // 默认红色
        _BitangentColor ("Bitangent Color", Color) = (0, 1, 0, 1)// 默认绿色
    }
    SubShader
    {
        // 渲染队列放在靠后，或者作为 Overlay
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" "Queue"="Geometry+1" }
        LOD 100

        Pass
        {
            Name "Forward"
            Tags { "LightMode"="UniversalForward" }

            // 关闭剔除，确保无论从哪个角度都能看到生成的线条
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            
            // 显式声明需要几何着色器支持
            #pragma require geometry

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
            };

            // 顶点着色器 -> 几何着色器的结构体
            struct VertexOutput
            {
                float3 positionWS   : TEXCOORD0;
                float3 normalWS     : TEXCOORD1;
                float3 tangentWS    : TEXCOORD2;
                float3 bitangentWS  : TEXCOORD3;
            };

            // 几何着色器 -> 片元着色器的结构体
            struct GeomOutput
            {
                float4 positionCS   : SV_POSITION;
                float4 color        : COLOR;
            };

            CBUFFER_START(UnityPerMaterial)
                float _ShowNormal;
                float _ShowTangent;
                float _ShowBitangent;
                float _VectorLength;
                float4 _NormalColor;
                float4 _TangentColor;
                float4 _BitangentColor;
            CBUFFER_END

            // ---------------- 顶点着色器 ----------------
            VertexOutput vert (Attributes input)
            {
                VertexOutput output;
                
                // 将顶点位置转到世界空间
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);

                // 获取世界空间的 TBN
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.normalWS = normalInput.normalWS;
                output.tangentWS = normalInput.tangentWS;
                output.bitangentWS = normalInput.bitangentWS;

                return output;
            }

            // ---------- 辅助函数：发射一条线段 ----------
            void EmitDebugLine(float3 startPosWS, float3 directionWS, float4 lineColor, inout LineStream<GeomOutput> outStream)
            {
                GeomOutput p0, p1;

                // 起点：顶点位置
                p0.positionCS = TransformWorldToHClip(startPosWS);
                p0.color = lineColor;
                
                // 终点：顶点位置 + 向量方向 * 长度
                p1.positionCS = TransformWorldToHClip(startPosWS + normalize(directionWS) * _VectorLength);
                p1.color = lineColor;

                outStream.Append(p0);
                outStream.Append(p1);
                outStream.RestartStrip(); // 结束当前线段
            }

            // ---------------- 几何着色器 ----------------
            // 每个三角形有 3 个顶点。每个顶点最多发射 3 条线（N, T, B）。每条线 2 个顶点。
            // 因此最大顶点数为：3 * 3 * 2 = 18。
            [maxvertexcount(18)]
            void geom(triangle VertexOutput input[3], inout LineStream<GeomOutput> outStream)
            {
                for(int i = 0; i < 3; i++)
                {
                    float3 posWS = input[i].positionWS;

                    if (_ShowNormal > 0.5)
                        EmitDebugLine(posWS, input[i].normalWS, _NormalColor, outStream);

                    if (_ShowTangent > 0.5)
                        EmitDebugLine(posWS, input[i].tangentWS, _TangentColor, outStream);

                    if (_ShowBitangent > 0.5)
                        EmitDebugLine(posWS, input[i].bitangentWS, _BitangentColor, outStream);
                }
            }

            // ---------------- 片元着色器 ----------------
            half4 frag (GeomOutput input) : SV_Target
            {
                // 直接输出几何着色器传过来的颜色
                return input.color;
            }
            ENDHLSL
        }
    }
}