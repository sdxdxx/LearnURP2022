Shader "Hidden/PerObjectShadow/ShadowCasterDepth"
{
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }

            // 关闭深度写入和测试（因为我们没有绑定 Depth Buffer）
            ZTest Always
            ZWrite Off
            
            // 【修改建议】改为 Cull Off 以防止因矩阵镜像导致的剔除问题，确保能画出东西
            Cull Off 
            
            // 开启混合，操作为 Min (保留最小值)
            // 背景已清除为 1.0(白)，物体像素为 0.x(黑)，Min 会保留物体
            BlendOp Min
            Blend One One 

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
            };

            Varyings vert(Attributes v)
            {
                Varyings o;
                o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);
                return o;
            }

            float frag(Varyings i) : SV_Target
            {
                // SV_POSITION.z 在这里是 Screen Space Depth
                float z = i.positionHCS.z;

                // 标准化深度输出：确保 0.0 代表 Near，1.0 代表 Far
                // 这样 BlendOp Min 才能正确保留“更近”的像素
                
                // 如果平台是 Reverse Z (DX11/12, Metal, Vulkan 等)，z 范围是 1(Near)..0(Far)
                // 我们需要把它翻转回 0(Near)..1(Far)
                #if UNITY_REVERSED_Z
                    z = 1.0 - z;
                #endif

                // 此时 z: 0.0(近/黑) -> 1.0(远/白)
                return saturate(z);
            }
            ENDHLSL
        }
    }
}