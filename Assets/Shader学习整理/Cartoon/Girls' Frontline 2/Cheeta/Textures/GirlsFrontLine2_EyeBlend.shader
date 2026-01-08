Shader "URP/NPR/GirlsFrontLine2/EyeBlend"
{
    Properties
    {
    	//Mode
    	[Header(BlendMode)]
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendSrc("Blend Src Factor", float) = 5   //SrcAlpha
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendDst("Blend Dst Factor", float) = 10  //OneMinusSrcAlpha
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", float) = 2 //Back
    	
    	[Header(Main Layer)]
    	_MainTex("Main Texture",2D) = "white"{}
    	
    	[Header(PBR)]
        _ColorTint("Color Tint",Color) = (1.0,1.0,1.0,1.0)
    	[Toggle(_ENABLE_RMO_MAP)]_EnableRMOMap("Enable RMO",float) = 1
    	_RMOMap("Roughness Metallic Occlusion Texture",2D) = "white"{}
    	_Smoothness("Smoothness",Range(0,1)) = 0
    	_Metallic("Metallic",Range(0,1)) = 0
    	_AOInt("Ambient Occlusion Intensity",Range(0,1)) = 1
    	
    	[Header(Normal)]
    	_NormalMap("Normal Map",2D) = "bump"{}
    	_NormalInt("Normal Intensity",Range(0,5)) = 1
	    
    	[Header(Ramp)]
    	_RampTex("Ramp Texture",2D) = "white"{}
    	
    	
    	[Header(Matcap)]
    	_MetalMatCap("Metal Mat Cap",2D) = "black"{}
    	_SatinMatCap("Satin Mat Cap",2D) = "black"{}
    	_MatCapLerp("Mat Cap Lerp",Range(0,1)) = 0.5
	    
    	_Test("Test",Range(0,1)) = 0
    }
    
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
        	"Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"  
        }

        //解决深度引动模式Depth Priming Mode问题
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/DepthNormals"
    	
    	HLSLINCLUDE
    		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
    		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
    	

    		#pragma multi_compile  _MAIN_LIGHT_SHADOWS
    		#pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
    		#pragma multi_compile  _SHADOWS_SOFT
    		
    		#pragma shader_feature_local _ENABLE_RMO_MAP
    	
    		#define kDielectricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04)
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);//定义贴图
            SAMPLER(sampler_MainTex);//定义采样器
    		TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
    		TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
    		TEXTURE2D(_RMOMap);
            SAMPLER(sampler_RMOMap);
    		TEXTURE2D(_RampTex);
            SAMPLER(sampler_RampTex);
    		
    		TEXTURE2D(_MetalMatCap);
    		SAMPLER(sampler_MetalMatCap);
    		TEXTURE2D(_SatinMatCap);
    		SAMPLER(sampler_SatinMatCap);
    	
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _ColorTint;

    		float _NormalInt;
    		float4 _NormalMap_ST;
            
            float _Smoothness;
            float _Metallic;
    		float _AOInt;
    	
            half4 _RimCol;
            float _RimWidth;
    	
            float4 _MainTex_ST;
    		
    		float _MatCapLerp;
    		float _Test;
            //----------变量声明结束-----------
            CBUFFER_END
    		
            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            	float4 tangent : TANGENT;
            	float4 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 nDirWS : TEXCOORD1;
                float3 posWS : TEXCOORD2;
            	float4 screenPos : TEXCOORD3;
            	float3 tDirWS : TEXCOORD4;
            	float3 bDirWS : TEXCOORD5;
            	float4 color : TEXCOORD6;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
            	float4 posCS = TransformObjectToHClip(v.vertex.xyz);
                o.pos = posCS;
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                o.posWS = TransformObjectToWorld(v.vertex);
            	o.screenPos = ComputeScreenPos(posCS);
            	o.tDirWS = normalize(TransformObjectToWorld(v.tangent));
            	o.bDirWS = normalize(cross(o.nDirWS,o.tDirWS)*v.tangent.w);
            	o.color = v.color;
                return o;
            }
    		
            half4 frag (vertexOutput i) : SV_TARGET
            {
            	//MainTex
            	float2 mainTexUV = i.uv *_MainTex_ST.xy+_MainTex_ST.zw;
                half4 albedo = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,mainTexUV);
            	albedo.rgb *=_ColorTint.rgb; 
            	return albedo.rgba;
            }
    	ENDHLSL

        pass
        {
	        Tags{"LightMode"="UniversalForward"}
            Blend [_BlendSrc] [_BlendDst]
			Cull  [_CullMode]
			ZTest Always
			ZWrite Off
             
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            ENDHLSL
        }

		pass
        {
	        Tags{"LightMode"="Meta"}
            
            cull off
             
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            ENDHLSL
        }
        
		//使用官方的ShadowCaster
		Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }
            
            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // Includes
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            // -------------------------------------
            
            ENDHLSL
        }
		
    }
}