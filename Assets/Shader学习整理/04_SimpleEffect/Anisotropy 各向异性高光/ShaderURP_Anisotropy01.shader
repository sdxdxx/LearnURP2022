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
                o.tDirWS = TransformObjectToWorld(v.tangent.xyz);
                o.bDirWS = cross(o.nDirWS,o.tDirWS)*v.tangent.w;
                o.uv = v.uv*_MainTex_ST.xy+_MainTex_ST.zw;
                o.posOS = v.vertex.xyz;
                
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                float3 posWS = TransformObjectToWorld(i.posOS);
                
                float3x3 TBN = float3x3(
                    i.tDirWS.x,i.bDirWS.x,i.nDirWS.x,
                    i.tDirWS.y,i.bDirWS.y,i.nDirWS.y,
                    i.bDirWS.z,i.bDirWS.z,i.bDirWS.z
                    );

                float3 tDirWS = normalize(i.tDirWS);
                float3 bDirWS = normalize(i.bDirWS);
                
                float3 nDir = i.nDirWS;
                float3 lDir= _MainLightPosition.xyz;
                float3 vDir = normalize(_WorldSpaceCameraPos.xyz - posWS.xyz);
                float3 hDir = normalize(lDir + vDir);
                
                //副切线向量与半角向量点乘高光
                float bDoth = dot(bDirWS, hDir);
                float bDoth_Rervese = 1-bDoth;
                float bDoth_Dark = smoothstep(-1,0,bDoth);

                //获得拉丝高光渐变
                float Ramp_Anisotropy = bDoth_Rervese * bDoth_Dark;
                
                half4 albedo = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv);
                half3 FinalRGB = albedo.rgb*_BaseColor.rgb*bDoth*Ramp_Anisotropy;
                half4 result = half4(Ramp_Anisotropy.xxx,1.0);
                return result;
            }
            
            ENDHLSL
        }
    }
}