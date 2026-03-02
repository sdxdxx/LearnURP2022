Shader "URP/Cartoon/DoublePassRim"
{
    Properties
    {
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _MainTex("MainTex",2D) = "white"{}
        _CurvatureTex("CurvatureTex",2D) = "black"{}
        _RimColor("Outline Color",Color) = (0.0,0.0,0.0,0.0)
        _RimScale("Rim Scale",Range(-5,20)) = 1
        _OffsetX("Offset X", Range(-10, 10)) = 0
        _OffsetY("Offset Y", Range(-10, 10)) = 0
        _OffsetZ("Offset Z", Range(-10, 10)) = 0
        _FresnelPow("Fresnel Pow", Range(1,10)) = 1
        _StepValue("Step Value",Range(0,1)) = 0
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
            Cull Back
            Tags { "LightMode" = "UniversalForward" }
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);//定义贴图
            SAMPLER(sampler_MainTex);//定义采样器
            TEXTURE2D(_CurvatureTex);//定义贴图
            SAMPLER(sampler_CurvatureTex);//定义采样器
            //----------贴图声明结束-----------
            
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float4 _MainTex_ST;
            float _FresnelPow;
            float _StepValue;
            //----------变量声明结束-----------
            CBUFFER_END

            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 nDirWS : TEXCOORD1;
                float3 posWS : TEXCOORD2;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv*_MainTex_ST.xy+_MainTex_ST.zw;
                float3 posWS = TransformObjectToWorld(v.vertex.xyz);
                o.posWS = posWS;
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                float curvatureTex = SAMPLE_TEXTURE2D(_CurvatureTex,sampler_CurvatureTex,i.uv);
                
                float3 vDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
                float3 posVS = TransformWorldToView(i.posWS);
                float3 nDir = NormalizeNormalPerPixel(i.nDirWS);
                float3 lDir = _MainLightPosition;
                float nDotl = dot(nDir,lDir);
                float nDotv = dot(nDir,vDir);
                float fresnel = pow(1-max(0,nDotv),_FresnelPow);
                fresnel = step(_StepValue,fresnel);
                float lambert = step(_StepValue,nDotl);
                half4 albedo = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv);
                return albedo*_BaseColor;
            }
            
            ENDHLSL
        }

        pass
        {
            Name "Rim"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            Cull Back
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);//定义贴图
            SAMPLER(sampler_MainTex);//定义采样器
            TEXTURE2D(_CurvatureTex);//定义贴图
            SAMPLER(sampler_CurvatureTex);//定义采样器
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float4 _MainTex_ST;
            half4 _RimColor;
            float _RimScale;
            float _OffsetX;
             float _OffsetY;
             float _OffsetZ;
            //----------变量声明结束-----------
            CBUFFER_END

            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float3 color : COLOR;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float3 nDirWS : TEXCOORD1;
                float3 posWS : TEXCOORD2;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                v.vertex.xyz = v.vertex.xyz+v.color* _RimScale;
                float3 posWS = TransformObjectToWorld(v.vertex);
                float3 posVS = TransformWorldToView(posWS);
                posVS.xyz += float3(_OffsetX,_OffsetY,_OffsetZ);
                posWS = TransformViewToWorld(posVS);
                v.vertex.xyz = TransformWorldToObject(posWS);
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.posWS = posWS;
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                // float3 vDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
                // float3 nDir = NormalizeNormalPerPixel(i.nDirWS);
                // float3 nDotv = dot(nDir,vDir);
                // float3 fresnel = pow(1-max(0,nDotv),1);
                // clip(fresnel-0.9);
                return _RimColor;
            }
            
            ENDHLSL
        }
    }
}