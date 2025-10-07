Shader "URP/VFX/WaterBubble"
{
    Properties
    {
        [Header(Mode)]
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendSrc("Blend Src Factor", float) = 5   //SrcAlpha
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendDst("Blend Dst Factor", float) = 10  //OneMinusSrcAlpha
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", float) = 2 //Back
        
        [Space(20)]
        
        [Header(MainTex)]
        _MainTex("MainTex",2D) = "white"{}
        
        [Space(20)]
        
        [Header(Parameter)]
        [HDR]_BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _AlphaClip("Alpha Clip",Range(0,1)) = 0
        
    }
    
    SubShader
    {
         Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
        }
         
         pass
        {
            Tags
            {
                "Name" = "Water Bubble"
                "LightMode" = "UniversalForward"
            }
            Lighting Off
            Blend [_BlendSrc] [_BlendDst]
            Cull[_CullMode]
            ZWrite Off
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature _EnableFrameTexture
            
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float4 _MainTex_ST;
            float _AlphaClip;
            //----------变量声明结束-----------
            CBUFFER_END

            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 nDirWS : TEXCOORD1;
                float4 color : TEXCOORD2;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                o.color = v.color;
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                float2 mainTexUV = i.uv *_MainTex_ST.xy+_MainTex_ST.zw;
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainTexUV);
                half4 albedo = mainTex;
                clip(albedo.a-_AlphaClip);
                float4 result = float4(albedo.rgb*i.color.rgb*_BaseColor.rgb,albedo.a*i.color.a);
                return result;
            }
            
            ENDHLSL
        }
    }
}