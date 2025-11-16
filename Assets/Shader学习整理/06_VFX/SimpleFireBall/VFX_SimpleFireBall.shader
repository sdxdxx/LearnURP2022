Shader "URP/VFX/SimpleFireBall"
{
    Properties
    {
        [Header(Mode)]
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendSrc("Blend Src Factor", float) = 5   //SrcAlpha
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendDst("Blend Dst Factor", float) = 10  //OneMinusSrcAlpha
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", float) = 2 //Back
        
        [HDR]_TintColor ("Tint Color", Color) = (1,1,1,1)
        _MainTex ("Particle Texture", 2D) = "white" {}
        _Speed("Speed(XY)", Vector) = (0,0,0,0)
        _MainTexPow("Main Texture Power", Range(1,10)) = 1
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
            ColorMask RGB
            Blend [_BlendSrc] [_BlendDst]
            Cull[_CullMode]
            Lighting Off
            ZWrite Off
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _TintColor;
            half4 _Speed;
            half _MainTexPow;
            float4 _MainTex_ST;
            //----------变量声明结束-----------
            CBUFFER_END
            
            struct vertexInput
            {
                float4 vertex : POSITION;
                half4 color : COLOR;
                float4 texcoord : TEXCOORD0;
                float4 texcoord1 : TEXCOORD1;
            };

            struct vertexOutput
            {
                float4 vertex : SV_POSITION;
                half4 color : COLOR;
                float4 texcoord : TEXCOORD0;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.color = v.color;
                o.texcoord.xy = TRANSFORM_TEX(v.texcoord,_MainTex);
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                float2 uv = i.texcoord.xy*_MainTex_ST.xy+_MainTex_ST.zw+_Speed.xy*_Time.z;
                half mainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv).r;
                half4 result = pow(mainTex,_MainTexPow)*_TintColor*i.color;
               return result;
            }
            
            ENDHLSL
        }
    }
}