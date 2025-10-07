Shader "Custom/2D/Flash"
{
    Properties
    {
        [HideInInspector]_MainTex ("Sprite Texture", 2D) = "white" {}
        
        //Debug
        [HideInInspector][Toggle(_EnableDebugMode)] _EnableDebugMode("_Enable Debug Mode",Float)= 0
        [HideInInspector]_Offset("Flash Offset (Debug) ",Range(0,1)) = 0.5
        
        //Custom Mask
        [HideInInspector][Toggle(_EnableCustomMask)] _EnableCustomMask("Enable Custom Mask",Float)= 0
        [HideInInspector]_CustomMask("Custom Mask", 2D) = "black"{}
        [HideInInspector]_CustomMaskScale("Custom Mask Scale",Range(0.5,2)) = 1
        
        //Code Mask
        [HideInInspector]_Width("Flash Width",Range(0,1)) = 0.26
        [HideInInspector]_Smooth("Smooth Flash",Range(0,1)) = 0.5
        
        //Mask Settings
        [HideInInspector][Toggle(_EnableAddMode)] _EnableAddMode("Enable Add Mode",Float)= 1
        [HideInInspector][HDR]_FlashColor ("Flash Color", Color) = (1,1,1,1)
        [HideInInspector]_AlphaCullValue("Alpha Cull Value", Range(0,1)) = 1
        [HideInInspector]_Angle("Flash Rotate Angle",Range(0,1)) = 0
        [HideInInspector]_FlashIntensity("Flash Intensity", Range(0,1)) = 1
        
        //Time
        [HideInInspector]_FlashTime("Flash Time",Range(0,30)) = 5
        [HideInInspector]_DelayTime("Delay Time",Range(0,30)) = 2.5

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

 			#pragma shader_feature _EnableAddMode
            #pragma shader_feature _EnableDebugMode
            #pragma shader_feature _EnableCustomMask
		
 			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

 			float2x2 AngleRotateMatrix(float Angle)
            {
                float angle = 1-Angle;
                float rotateCos = cos(angle*2*PI);
                float rotateSin = sin(angle*2*PI);
                float2x2 rotate = float2x2(rotateCos,-rotateSin,rotateSin,rotateCos);
                return rotate;
            }

            float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
             {
               return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
             }
		
            struct Attributes
            {
                float3 positionOS   : POSITION;
                float4 color        : COLOR;
                float2 uv           : TEXCOORD0;
 			    float2 uv1          : TEXCOORD1;
            };

            struct Varyings
            {
                float4  positionCS  : SV_POSITION;
                half4   color       : COLOR;
                float2  uv          : TEXCOORD0;
                float2  uv1         : TEXCOORD1;
                float3  positionWS  : TEXCOORD2;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
 			TEXTURE2D(_CustomMask);
 			SAMPLER(sampler_CustomMask);
 			half4 _MainTex_ST;
            float _CustomMaskScale;
            float _FlashSpeed;
            int _DelayScale;
            float _FlashTime;
            float _DelayTime;
            float _FlashIntensity;
            half4 _FlashColor;
            float _Width;
            float _Smooth;
            float _Angle;
            float _Offset;
            float _AlphaCullValue;
 			
            float4 _Color;
            half4 _RendererColor;
            float4 _MainTex_TexelSize;
            float _Light;
		
            Varyings UnlitVertex(Attributes v)
            {
                Varyings o = (Varyings)0;
                o.positionCS = TransformObjectToHClip(v.positionOS);
                o.positionWS = TransformObjectToWorld(v.positionOS);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.uv1 = v.uv1;
                o.color = v.color * _Color * _RendererColor;
                return o;
            }

            half4 UnlitFragment(Varyings i) : SV_Target
            {
                float4 mainTex = i.color * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);

                float customMaskTilling = 1/(_CustomMaskScale+0.0001f);

                //计算周期函数
                float customPeriodicFunction = remap(fmod(_Time.y,(_FlashTime+_DelayTime)*0.5),0,_FlashTime*0.5,0,1.0f);//此时处于Delay状态时值为1
                float modifyPeriodFunction = step(customPeriodicFunction,1);
                customPeriodicFunction *= modifyPeriodFunction;
                customPeriodicFunction *= (customMaskTilling.x+1)*(0.5f/customMaskTilling.x);
                
                #ifdef _EnableDebugMode
                customPeriodicFunction = _Offset*(customMaskTilling.x+1)*(0.5f/customMaskTilling.x);
                #endif
                
                float flashMask;
                #ifndef _EnableCustomMask
                //计算遮罩
                //计算FlashUV
                float2 flashUV = i.uv1+(customPeriodicFunction*2-1);
                float2 UVCenter = float2(0.5,0.5)+(customPeriodicFunction*2-1);
                float2x2 rotateMatrix = AngleRotateMatrix(_Angle);
                flashUV = mul(flashUV-UVCenter,rotateMatrix)+UVCenter;
                //计算FlashMask
                float width = _Width;
                float hardWidthProportion = 1-_Smooth;
                flashMask = 1-abs(flashUV.x*2-1);
                flashMask = smoothstep(saturate(1-width),saturate(1-width*hardWidthProportion),flashMask)*_FlashIntensity;
                #else
                //自定义遮罩
                float2 flashUV = i.uv1*customMaskTilling;
                flashUV.x += (customPeriodicFunction*2-1)*customMaskTilling;
                float2 UVCenter = float2(0.5,0.5)*customMaskTilling;
                UVCenter.x += (customPeriodicFunction*2-1)*customMaskTilling;
                float2x2 rotateMatrix = AngleRotateMatrix(_Angle);
                flashUV = mul(flashUV-UVCenter,rotateMatrix)+UVCenter;
                flashUV = saturate(flashUV);
                flashMask = SAMPLE_TEXTURE2D(_CustomMask, sampler_CustomMask, flashUV).a * _FlashIntensity;
                #endif
                flashMask *= smoothstep(_AlphaCullValue-0.1,_AlphaCullValue,mainTex.a);
                
                half3 FinalRGB;
                #ifdef _EnableAddMode
                FinalRGB = (mainTex+flashMask*_FlashColor*mainTex).rgb;
                #else
                FinalRGB = lerp(mainTex,_FlashColor,flashMask).rgb;
                #endif
                
                half4 result = half4(FinalRGB,mainTex.a);
                
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

    CustomEditor "FlashGUI"
}
