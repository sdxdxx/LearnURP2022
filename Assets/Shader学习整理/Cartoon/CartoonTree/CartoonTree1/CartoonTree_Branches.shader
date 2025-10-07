Shader "URP/CartoonTree/Branches"
{
    Properties
    {
    	_MainTex("Main Texture",2D) = "white"{}
    	
    	[Header(Diffuse)]
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _DarkColor("Dark Color",Color) = (0,0,0,1.0)
        
    	[Header(Specular)]
    	_SpecPow("Specular Power",Range(1,50)) = 1
    	_SpecInt("Specular Intensity",Range(0,1)) = 1
        _SpecCol("Specular Color",Color) = (1,1,1,1)
        
    	[Header(Rim)]
    	_RimPow("Rim Power",Range(1,50)) = 1
        _RimInt("Rim Intensity",Range(0,1)) = 1
        _RimCol("Rim Color",Color) = (1,1,1,1)
    	
    	[Header(Wind)]
    	_WindDistortionMap("Wind Distortion Map", 2D) = "white" {}
        _WindFrequency("Wind Frequency", Vector) = (0.05, 0.05, 0, 0)
    	_WindStrength("Wind Strength", Range(0,1)) = 1
    }
    
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"  
        }

        //解决深度引动模式Depth Priming Mode问题
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/DepthNormals"
    	
    	HLSLINCLUDE
    		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

    		#pragma multi_compile  _MAIN_LIGHT_SHADOWS
    		#pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
    		#pragma multi_compile  _SHADOWS_SOFT
    	
    		#define kDielectricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04)
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);//定义贴图
            SAMPLER(sampler_MainTex);//定义采样器
             TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_WindDistortionMap);
			SAMPLER(sampler_WindDistortionMap);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            half4 _DarkColor;
            
            float _SpecPow;
            float _SpecInt;
            half4 _SpecCol;

            half4 _RimCol;
    		float _RimPow;
            float _RimInt;

            float _WindStrength;
            float2 _WindFrequency;
            float4 _WindDistortionMap_ST;
            
            float4 _MainTex_ST;
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
                float3 nDirOS : TEXCOORD1;
                float3 posWS : TEXCOORD2;
            	float4 screenPos : TEXCOORD3;
            	float4 shadowCoord : TEXCOORD4;
            };

            vertexOutput vert (vertexInput v)
            {
            	float3 posWS = TransformObjectToWorld(v.vertex);
            	float windStrength = _WindStrength+0.001f;
            	float2 windUV = posWS.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;
		        float3 windSample = (SAMPLE_TEXTURE2D_LOD(_WindDistortionMap,sampler_WindDistortionMap, windUV,0).xyz * 2 - 1);
		        float3 wind = normalize(windSample)* windStrength*0.3;
		        
            	
                vertexOutput o;
            	v.vertex.xyz = v.vertex.xyz +wind;
            	float4 posCS = TransformObjectToHClip(v.vertex.xyz);
                o.pos = posCS;
                o.nDirOS = v.normal;
                o.uv = v.uv;
                o.posWS = TransformObjectToWorld(v.vertex);
            	o.screenPos = ComputeScreenPos(posCS);
            	o.shadowCoord = TransformWorldToShadowCoord(o.posWS);
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                float3 nDirWS = TransformObjectToWorldNormal(i.nDirOS);
            	nDirWS = abs(nDirWS);
            	float3 nDirVS = TransformWorldToView(nDirWS);
                float3 lDirWS = _MainLightPosition.xyz;
                float3 vDirWS = normalize(_WorldSpaceCameraPos - i.posWS);
                float3 nDotl = dot(nDirWS,lDirWS);
                float halfLambert = nDotl*0.5+0.5;
            	float2 mainTexUV = i.uv *_MainTex_ST.xy+_MainTex_ST.zw;
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,mainTexUV);
                half3 albedo = mainTex.rgb*_BaseColor*mainTex.a;

            	//alpha clip
            	
                clip(mainTex.a-0.1);


            	//dark color
            	float darkCol = _DarkColor*mainTex.rgb*mainTex.a;
            	
            	//diffuse
                half3 diffuse= lerp(darkCol,albedo,halfLambert);

            	//specular
            	float3 hDirWS = normalize(lDirWS+vDirWS);
            	float nDoth = dot(nDirWS,hDirWS);
            	half3 specCol = pow(saturate(nDoth),_SpecPow)*_SpecInt*_SpecCol;
            	
            	//rim
            	float nDotv = dot(nDirWS,vDirWS);
            	half3 rim = pow(1-saturate(nDotv),_RimPow)*_RimInt*_RimCol;

            	//shadow
            	float shadow = MainLightRealtimeShadow(i.shadowCoord);
            	
            	half3 FinalRGB = diffuse+rim+specCol;
            	FinalRGB = lerp(FinalRGB*_DarkColor,FinalRGB,shadow);
                return half4(FinalRGB,1.0);
            }
    	ENDHLSL
        
        pass
        {
	        Tags{"LightMode"="UniversalForward"}
            
            cull off
             
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            ENDHLSL
        }
    	
    	// shadow casting pass with empty fragment
		Pass
		{
		Name "GrassShadowCaster"
		Tags{ "LightMode" = "ShadowCaster" }

		ZWrite On
		ZTest LEqual

		HLSLPROGRAM

		 #pragma vertex vert
		#pragma fragment frag_shadow
		
		#pragma target 4.6

		half4 frag_shadow(vertexOutput i) : SV_TARGET
		{
			//alpha clip
			float2 mainTexUV = i.uv *_MainTex_ST.xy+_MainTex_ST.zw;
			half4 mainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,mainTexUV);
			clip(mainTex.a-0.1);
			return 1;
		 }

		ENDHLSL
		}
    }
}