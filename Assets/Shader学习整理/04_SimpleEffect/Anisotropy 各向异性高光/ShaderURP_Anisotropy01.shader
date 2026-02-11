Shader "URP/SimpleEffect/Anisotropy01"
{
    Properties
    {
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _MainTex("MainTex",2D) = "white"{}
    }
    
    SubShader
    {
         Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }
    	
    	//解决深度引动模式Depth Priming Mode问题
        UsePass "Universal Render Pipeline/Unlit/DepthOnly"
        UsePass "Universal Render Pipeline/Unlit/DepthNormalsOnly"

         pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);//定义贴图
            SAMPLER(sampler_MainTex);//定义采样器
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float4 _MainTex_ST;
            //----------变量声明结束-----------
            CBUFFER_END

            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 nDirWS : TEXCOORD1;
                float3 tDirWS : TEXCOORD2;
                float3 bDirWS : TEXCOORD3;
                float3 posOS : TEXCOORD4;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.tDirWS = normalize(TransformObjectToWorldDir(v.tangent.xyz));
                o.bDirWS = normalize(cross(o.nDirWS,o.tDirWS))*v.tangent.w;
                o.uv = v.uv*_MainTex_ST.xy+_MainTex_ST.zw;
                o.posOS = v.vertex.xyz;
                
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                float3 posWS = TransformObjectToWorld(i.posOS);
                
                // 1. 移除了没用的 TBN 矩阵定义，保持整洁

                float3 tDirWS = normalize(i.tDirWS);
                float3 bDirWS = normalize(i.bDirWS);
                float3 nDir = normalize(i.nDirWS);
                
                float3 lDir = _MainLightPosition.xyz; // 假设是平行光
                float3 vDir = normalize(_WorldSpaceCameraPos.xyz - posWS.xyz);
                float3 hDir = normalize(lDir + vDir);
                
                // --- 你的拟合算法核心 (这部分逻辑作为近似是没问题的) ---
                float bDoth = dot(tDirWS, hDir);
                float Ramp_Anisotropy = 1.0 - abs(bDoth);
                Ramp_Anisotropy = pow(saturate(Ramp_Anisotropy), 5.0); // 建议加上这一步控制粗细
                
                // 1. 计算基础漫反射 (受光面)
                float NdotL = saturate(dot(nDir, lDir));
                
                half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                
                // 2. 漫反射部分
                half3 Diffuse = albedo.rgb * _BaseColor.rgb * NdotL;
                
                // 3. 高光部分 (通常高光要乘以光源颜色，且要受 NdotL 遮蔽，防止阴影面发光)
                half3 Specular = _BaseColor.rgb * Ramp_Anisotropy * NdotL; // 简单的金属风格叠加
                
                // 4. 最终结果：漫反射 + 高光
                half3 FinalRGB = Diffuse + Specular;

                return half4(FinalRGB, 1.0);
            }
            
            ENDHLSL
        }
    }
}