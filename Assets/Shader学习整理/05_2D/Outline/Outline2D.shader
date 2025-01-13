Shader "URP/2D/Inline"
{
    Properties
    {
        _MainTex ("Sprite Texture", 2D) = "white" {}
        
        _InlineColor("InlineColor",Color) = (0,0,0,1)
        _InlineWidth("InlineWidth",Range(0,10)) = 1
        _Light("Light",Range(1,5)) = 1

        // Legacy properties. They're here so that materials using this shader can gracefully fallback to the legacy sprite shader.
        [HideInInspector] _Color ("Tint", Color) = (1,1,1,1)
        [HideInInspector] PixelSnap ("Pixel snap", Float) = 0
        [HideInInspector] _RendererColor ("RendererColor", Color) = (1,1,1,1)
        [HideInInspector] _Flip ("Flip", Vector) = (1,1,1,1)
        [HideInInspector] _AlphaTex ("External Alpha", 2D) = "white" {}
        [HideInInspector] _EnableExternalAlpha ("Enable External Alpha", Float) = 0
    }

    SubShader
    {
        Tags {"Queue" = "Transparent" "RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" }

        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off
        ZWrite Off

		HLSLINCLUDE
		
 			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		
            struct Attributes
            {
                float3 positionOS   : POSITION;
                float4 color        : COLOR;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float4  positionCS  : SV_POSITION;
                half4   color       : COLOR;
                float2  uv          : TEXCOORD0;
                float3  positionWS  : TEXCOORD2;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            half4 _MainTex_ST;
            float4 _Color;
            half4 _RendererColor;
            float4 _MainTex_TexelSize;
            float4 _InlineColor;
            float _InlineWidth;
            float _Light;
		
            Varyings UnlitVertex(Attributes v)
            {
                Varyings o = (Varyings)0;
                o.positionCS = TransformObjectToHClip(v.positionOS);
                o.positionWS = TransformObjectToWorld(v.positionOS);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.color = v.color * _Color * _RendererColor;
                return o;
            }

            half4 UnlitFragment(Varyings i) : SV_Target
            {
                float4 mainTex = i.color * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                //获取周围上下左右4个点的uv
                 float2 up_uv = i.uv + float2(0,_InlineWidth * _MainTex_TexelSize.y);
                 float2 down_uv = i.uv + float2(0,-_InlineWidth * _MainTex_TexelSize.y);
                 float2 left_uv = i.uv + float2(-_InlineWidth * _MainTex_TexelSize.x,0);
                 float2 right_uv = i.uv + float2(_InlineWidth * _MainTex_TexelSize.x,0);
                 
                  //根据uv,获取周围上下左右4个点的alpha乘积
                 float arroundAlpha = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,up_uv).a *
                 SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,down_uv).a *
                 SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,left_uv).a *
                 SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,right_uv).a;

                 //让描边变色
                 float4 result = lerp(_InlineColor * _Light,mainTex,arroundAlpha);
                 //使用原来的透明度
                 result.a = mainTex.a;
                                 
                 //上面的代码在_InlineWidth = 0时，仍然有一丝描边的颜色。这里控制一下
                 float threshold  = step(0.000001,_InlineWidth);
                 result = lerp(mainTex,result,threshold);
                
                return result;
            }
		ENDHLSL

        Pass
        {
            Tags { "LightMode" = "Universal2D" }
            
            HLSLPROGRAM
			#pragma vertex UnlitVertex
            #pragma fragment UnlitFragment
            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "UniversalForward" "Queue"="Transparent" "RenderType"="Transparent"}

            HLSLPROGRAM
            #pragma vertex UnlitVertex
            #pragma fragment UnlitFragment
            ENDHLSL
        }
    }

    Fallback "Sprites/Default"
}
