Shader "URP/TestPerObjectShadow_Lambert"
{
    Properties
    {
        [Header(Base)]
        _BaseColor("Base Color", Color) = (1,1,1,1)
    }

    SubShader
    {
        Tags{ "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/DepthNormals"

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #pragma multi_compile  _MAIN_LIGHT_SHADOWS
			#pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile  _SHADOWS_SOFT
            
            // 确保定义了 UNITY_REVERSED_Z 宏
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            
            // ... (Uniforms 保持不变) ...
            TEXTURE2D(_CharacterShadowAtlas);
            SAMPLER(sampler_CharacterShadowAtlas);
            float4 _CharacterShadowAtlas_TexelSize;
            float4x4 _CharacterShadowMatrix[9];
            float4   _CharacterUVClamp[9];
            int      _CharacterShadowCount;
            float4 _PerObjectShadowBiasGen;

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
            CBUFFER_END

            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct vertexOutput
            {
                float4 pos   : SV_POSITION;
                float3 posWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
            };

            vertexOutput vert(vertexInput v)
            {
                vertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.posWS = TransformObjectToWorld(v.vertex.xyz);
                o.normalWS = TransformObjectToWorldNormal(v.normal);
                return o;
            }

            // 【核心修正】
            void SampleShadowSingle(float3 positionWS, int idx, float depthBias,
                                   out float vis, out float inTile)
            {
                float4 sc = mul(_CharacterShadowMatrix[idx], float4(positionWS, 1.0));
                sc.xyz /= max(sc.w, 1e-6);

                float2 uv = sc.xy;
                
                // 1. receiverZ: 经过 C# Bias 处理，保证是 [0=Near, 1=Far]
                float receiverZ = sc.z;

                // 2. Tile 检查 (保持不变)
                float4 c = _CharacterUVClamp[idx];
                bool inside = (uv.x >= c.x && uv.x <= c.y && uv.y >= c.z && uv.y <= c.w);
                
                // 增加 Z 轴范围保护 (防止背后的物体投影回来)
                // 这里的 0 和 1 对应 Near 和 Far
                inside = inside && (receiverZ >= 0.0 && receiverZ <= 1.0); 
                
                inTile = inside ? 1.0 : 0.0;

                if (!inside)
                {
                    vis = 1.0;
                    return;
                }

                // UV Clamp (保持不变)
                float epsU = _CharacterShadowAtlas_TexelSize.x * 0.5;
                float epsV = _CharacterShadowAtlas_TexelSize.y * 0.5;
                uv.x = clamp(uv.x, c.x + epsU, c.y - epsU);
                uv.y = clamp(uv.y, c.z + epsV, c.w - epsV);

                // 3. 采样原始深度
                float rawZ = SAMPLE_TEXTURE2D(_CharacterShadowAtlas, sampler_CharacterShadowAtlas, uv).r;
                float storedZ = rawZ;

                // 【关键修正 1】: 统一硬件深度含义
                // 如果是 Reverse-Z (DX11/Metal)，硬件存的是 1(Near)->0(Far)
                // 我们要把它翻转成 0(Near)->1(Far) 来跟 receiverZ 对齐
                #if UNITY_REVERSED_Z
                    storedZ = 1.0 - rawZ;
                #endif

                // 【关键修正 2】: 比较逻辑修正
                // 现在 receiverZ 和 storedZ 都是 0=Near, 1=Far
                // 只有当 receiverZ <= storedZ (比遮挡物更近或一样) 时，才被照亮
                // 注意 Bias 的符号：我们希望物体稍微 "靠前" 一点点来避免自阴影，所以是 receiverZ <= storedZ + bias
                // 或者写成 standard PCF style: receiverZ - bias <= storedZ
                
                vis = (receiverZ <= storedZ + depthBias) ? 1.0 : 0.0;
            }

            float ComputePerObjectShadow(float3 positionWS, float3 normalWS)
            {
                // ... (Normal Bias 逻辑保持不变) ...
                // 注意：NormalBias 沿着法线推挤顶点，这会改变 positionWS
                // 从而改变 receiverZ。这部分逻辑是通用的，不需要改。
                
                float3 nWS = normalize(normalWS);
                float globalDepthBias  = _PerObjectShadowBiasGen.x;
                float globalNormalBias = _PerObjectShadowBiasGen.y;
                float3 shadowPosWS = positionWS + nWS * globalNormalBias;
                
                int count = _CharacterShadowCount;
                float finalVis = 1.0;

                if (count > 0)
                {
                    [unroll] // 循环必须展开以支持 Texture 数组采样(虽然这里是一张大图)
                    for (int idx = 0; idx < 10; idx++)
                    {
                        if (idx >= count) break;
                        float vis, inTile;
                        SampleShadowSingle(shadowPosWS, idx, globalDepthBias, vis, inTile);

                        // 简单的混合逻辑：如果在 Tile 内，就取阴影值
                        if (inTile > 0.5)
                        {
                            finalVis = min(finalVis, vis);
                        }
                    }
                }
                return finalVis;
            }

            half4 frag(vertexOutput i) : SV_TARGET
            {
                float3 normalWS = normalize(i.normalWS);
                
                // 计算自定义阴影
                float finalVis = ComputePerObjectShadow(i.posWS, normalWS);
                float4 shadowCoord = TransformWorldToShadowCoord(i.posWS);
                float shadow = MainLightRealtimeShadow(shadowCoord);
                
                // 【修正 3】 Lambert 漫反射必须乘 NdotL
                float NdotL = saturate(dot(normalWS, _MainLightPosition));
                
                float3 ambient = float3(0.1, 0.1, 0.1) * _BaseColor.rgb;
                
                // 只有被光照亮的地方(NdotL > 0) 且 没有被遮挡(finalVis=1) 才显示漫反射
                float3 diffuse = _BaseColor.rgb * NdotL * finalVis * shadow;
                
                return half4(ambient + diffuse, 1.0);
            }

            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            // -------------------------------------
            // Render State Commands
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Universal Pipeline keywords

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
    }
}