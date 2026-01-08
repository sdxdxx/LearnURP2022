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

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

            // PerObjectShadow globals
            TEXTURE2D(_CharacterShadowAtlas);
            SAMPLER(sampler_CharacterShadowAtlas);
            float4 _CharacterShadowAtlas_TexelSize;
            float4x4 _CharacterShadowMatrix[10];
            float4   _CharacterUVClamp[10];
            int      _CharacterShadowCount;

            // x: DepthBias (0-1 range), y: NormalBias (World Unit), z: unused, w: unused
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

            // 【核心阴影采样逻辑】
            void SampleShadowSingle(float3 positionWS, int idx, float depthBias,
                                   out float vis, out float inTile)
            {
                // 将世界坐标变换到 Shadow Atlas 的 UV 和 Depth 空间
                float4 sc = mul(_CharacterShadowMatrix[idx], float4(positionWS, 1.0));
                
                // 正交投影除以 w (虽然正交下 w 通常为 1，但保留除法更健壮)
                sc.xyz /= max(sc.w, 1e-6);

                float2 uv = sc.xy;
                
                // receiverZ 是当前像素点相对于光源的深度
                // C# 矩阵已处理好 API 差异，这里保证是  1(Near) -> 0(Far) 的线性值
                float  receiverZ = sc.z;
                
                // 简单的边界检查
                receiverZ = saturate(receiverZ);

                float4 c = _CharacterUVClamp[idx];
                bool inside = (uv.x >= c.x && uv.x <= c.y && uv.y >= c.z && uv.y <= c.w);
                inTile = inside ? 1.0 : 0.0;

                if (!inside)
                {
                    vis = 1.0;
                    return;
                }

                // 简单的内缩防止采样溢出
                float epsU = _CharacterShadowAtlas_TexelSize.x * 0.5;
                float epsV = _CharacterShadowAtlas_TexelSize.y * 0.5;
                uv.x = clamp(uv.x, c.x + epsU, c.y - epsU);
                uv.y = clamp(uv.y, c.z + epsV, c.w - epsV);

                // 采样原生 Shadowmap (Raw Depth)
                float rawZ = SAMPLE_TEXTURE2D(_CharacterShadowAtlas, sampler_CharacterShadowAtlas, uv).r;
                float storedZ = rawZ;


                // 比较逻辑：
                // 1(Near) -> 0(Far)
                // 如果 receiverZ (物体深度) >= storedZ (遮挡物深度) + bias，说明物体在遮挡物前面或重合 -> 被照亮(1.0)
                // 否则 -> 在阴影中(0.0)
                vis = (receiverZ >= storedZ + depthBias ) ? 1.0 : 0.0;
            }

            float ComputePerObjectShadow(float3 positionWS, float3 normalWS)
            {
                float3 nWS = normalize(normalWS);
                
                // 获取全局偏差设置
                float globalDepthBias  = _PerObjectShadowBiasGen.x;
                float globalNormalBias = _PerObjectShadowBiasGen.y;

                // 【Normal Bias 原理】
                // 沿着法线方向偏移采样点，防止“自身阴影斑点”(Shadow Acne)。
                // 但如果偏移过大(如 0.4m)，采样点就会穿过遮挡物，导致“阴影断层”(Peter Panning)。
                float3 shadowPosWS = positionWS + nWS * globalNormalBias;
                
                int count = _CharacterShadowCount;
                float finalVis = 1.0;

                if (count > 0)
                {
                    [unroll]
                    for (int idx = 0; idx < 10; idx++)
                    {
                        if (idx >= count) break;
                        float vis, inTile;
                        // 传入偏移后的位置进行采样
                        SampleShadowSingle(shadowPosWS, idx, globalDepthBias, vis, inTile);

                        finalVis = min(finalVis, vis);
                        if (finalVis < 0.5) break;
                    }
                }

                return finalVis;
            }

            half4 frag(vertexOutput i) : SV_TARGET
            {
                float3 normalWS = normalize(i.normalWS);
                
                float4 shadowCoord = TransformWorldToShadowCoord(i.posWS);
                float shadow = MainLightRealtimeShadow(shadowCoord);
                
                float finalVis = ComputePerObjectShadow(i.posWS, normalWS);
                
                
                Light mainLight = GetMainLight();
                float3 lightDir = mainLight.direction;
                float3 lightColor = mainLight.color;

                float NdotL = saturate(dot(normalWS, lightDir));
                float3 ambient = float3(0.1, 0.1, 0.1) * _BaseColor.rgb;
                float3 diffuse = _BaseColor.rgb * lightColor * NdotL * min(finalVis,1);
                float3 finalColor = ambient + diffuse;

                return half4(finalColor, 1.0);
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