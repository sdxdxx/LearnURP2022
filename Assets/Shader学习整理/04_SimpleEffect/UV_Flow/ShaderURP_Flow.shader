Shader "URP/SimpleEffect/UV_Flow"
{
    Properties
    {
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _MainTex("Main Texture",2D) = "white"{}
        _SpeedX("Speed X",float) = 1
        _SpeedY("Speed Y",float) = 1
    }
    
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "RenderPipeline" = "UniversalPipeline"  
        }

        //解决深度引动模式Depth Priming Mode问题
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/DepthNormals"
        
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
            float _SpeedX;
            float _SpeedY;
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
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv*_MainTex_ST.xy+_MainTex_ST.zw;
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                float2 uv_Flow = i.uv;
                uv_Flow.x += _SpeedX*_Time.x;
                uv_Flow.y += _SpeedY*_Time.y;
                
                half4 albedo = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv_Flow);
                return albedo*_BaseColor;
            }
            
            ENDHLSL
        }
    }
}