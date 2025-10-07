Shader "URP/CartoonTree/Flowers"
{
    Properties
    {
    	_MainTex("Main Texture",2D) = "white"{}
    	
    	[Header(Diffuse)]
        _ColorTint("Color Tint",Color) = (1.0,1.0,1.0,1.0)
        _TopColor("Top Color",Color) = (1.0,1.0,1.0,1.0)
        _BottomColor("Bottom Color",Color) = (0.3,0.3,0.3,1.0)
        _DarkColor("Dark Color",Color) = (0,0,0,1.0)
        
    	[Header(Specular)]
    	_Smoothness("Smoothness",Range(0,1)) = 0
    	_Metallic("Metallic",Range(0,1)) = 0
    	_SpecInt("Specular Intensity",Range(0,1)) = 1
        _SpecCol("Specular Color",Color) = (1,1,1,1)
    	
    	[Header(Scattering)]
    	_ScatteringDistoration("Scattering Distoration",float) = 1
    	_ScatteringPow("Scattering Power",Range(0,5)) = 1
    	_ScatteringInt("Scattering Intensity",Range(0,5)) = 1
    	
    	[Header(Rim)]
    	_RimCol("Rim Color",Color) = (1,1,1,1)
        _RimOffset("Rim Offset",float) = 1
    	
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
        	"Queue" = "Transparent"
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
            half4 _ColorTint;
            half4 _TopColor;
            half4 _BottomColor;
            half4 _DarkColor;
            
            float _Smoothness;
            float _Metallic;
            float _SpecInt;
            half4 _SpecCol;
            
            float _ScatteringDistoration;
            float _ScatteringPow;
            float _ScatteringInt;
    	
            float _WindStrength;
            float2 _WindFrequency;
            float4 _WindDistortionMap_ST;
            
            float4 _MainTex_ST;
            //----------变量声明结束-----------
            CBUFFER_END

            //直接光镜面反射部分
            float3 CalculateSpecularResultColor(float3 albedo, float3 nDir, float3 lDir, float3 vDir, float smothness, float metallic, float3 specCol)
            {

            	float hDir = normalize(vDir+lDir);

            	float nDotl = max(saturate(dot(nDir,lDir)),0.000001);
				float nDotv = max(saturate(dot(nDir,vDir)),0.000001);
				float hDotv = max(saturate(dot(vDir,hDir)),0.000001);
            	
            	//粗糙度一家
				float perceptualRoughness = 1 - smothness;//粗糙度
				float roughness = perceptualRoughness * perceptualRoughness;//粗糙度二次方
				float squareRoughness = roughness * roughness;//粗糙度四次方
            	
				//法线分布函数NDF
				float lerpSquareRoughness = pow(lerp(0.002,1,roughness),2);
				//Unity把roughness lerp到了0.002,
				//目的是保证在smoothness为0表面完全光滑时也会留有一点点高光

				float D = lerpSquareRoughness / (pow((pow(dot(nDir,hDir),2)*(lerpSquareRoughness-1)+1),2)*PI);

				//几何(遮蔽)函数
				float kInDirectLight = pow(roughness+1,2)/8;
				float kInIBL = pow(roughness,2)/2;//IBL：间接光照
				float Gleft = nDotl / lerp(nDotl,1,kInDirectLight);
				float Gright = nDotv / lerp(nDotv,1,kInIBL);
				float G = Gleft*Gright;

            	//菲涅尔方程
				float3 F0 = lerp(kDielectricSpec.rgb, albedo, metallic);//使用Unity内置函数计算平面基础反射率
				float3 F = F0 + (1 - F0) *pow((1-hDotv),5);
            	

            	float3 SpecularResult = (D*G*F)/(4*nDotv*nDotl);

				 //因为之前少给漫反射除了一个PI，为保证漫反射和镜面反射比例所以多乘一个PI
				float3 specColor = SpecularResult * specCol * nDotl * PI;

            	return specColor;
            }
            
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
            	//alpha clip
            	float2 mainTexUV = i.uv *_MainTex_ST.xy+_MainTex_ST.zw;
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,mainTexUV);
                clip(mainTex.a-0.1);
            	
                float3 nDirWS = TransformObjectToWorldNormal(i.nDirOS);
            	float3 nDirVS = TransformWorldToView(nDirWS);
                float3 lDirWS = _MainLightPosition.xyz;
                float3 vDirWS = normalize(_WorldSpaceCameraPos - i.posWS);
                float3 nDotl = dot(nDirWS,lDirWS);
                float halfLambert = nDotl*0.5+0.5;
                half3 albedo = lerp(_BottomColor,_TopColor,smoothstep(0.3,1,mainTex.x))*_ColorTint;
            	
            	//diffuse
                half3 diffuse= albedo;

            	//specular
            	half3 specCol = CalculateSpecularResultColor(albedo,nDirWS,lDirWS,vDirWS,_Smoothness,_Metallic,_SpecCol)*_SpecInt;

            	//scattering
            	float3 hDir2 = normalize(lDirWS+(nDirWS*0.5+0.5)*_ScatteringDistoration);
            	half3 scattering = saturate(pow(saturate(dot(vDirWS,-hDir2)),_ScatteringPow)*_ScatteringInt*albedo);
            	
            	//shadow
            	float shadow = MainLightRealtimeShadow(i.shadowCoord);
            	
            	half3 FinalRGB = saturate(diffuse+specCol+_MainLightColor*scattering);
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