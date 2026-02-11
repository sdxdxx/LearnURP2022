Shader "URP/NPR/GirlsFrontLine2/Stock"
{
    Properties
    {
    	[Header(Main Layer)]
    	_MainTex("Main Texture",2D) = "white"{}
    	
    	[Header(PBR)]
        _ColorTint("Color Tint",Color) = (1.0,1.0,1.0,1.0)
    	[Toggle(_ENABLE_RMO_MAP)]_EnableRMOMap("Enable RMO",float) = 1
    	_RMOMap("Roughness Metallic Occlusion Texture",2D) = "white"{}
    	_Smoothness("Smoothness",Range(0,1)) = 0
    	_Metallic("Metallic",Range(0,1)) = 0
    	_Anisotropy("Anisotropy",Range(-1,1)) = 0
    	_AOInt("Ambient Occlusion Intensity",Range(0,1)) = 1
    	
    	[Header(Normal)]
    	_NormalMap("Normal Map",2D) = "bump"{}
    	_NormalInt("Normal Intensity",Range(0,5)) = 1
	    
    	[Header(Ramp)]
    	_RampTex("Ramp Texture",2D) = "white"{}
    	
    	[Header(PerObjectShadow)]
        [IntRange]_Unit("Unit",Range(1,10)) = 1
	    
    	[Header(Matcap)]
    	_MetalMatCap("Metal Mat Cap",2D) = "black"{}
    	_SatinMatCap("Satin Mat Cap",2D) = "black"{}
    	_MatCapLerp("Mat Cap Lerp",Range(0,1)) = 0.5
	    
    	[Header(Outline)]
        _OutlineColor("Outline Color",Color) = (0.0,0.0,0.0,0.0)
        _OutlineWidth("Outline Width",Range(0,5)) = 1
    	_Test("Test",Range(-1,1)) = 0
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
    		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
    		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
    		#include "Assets/Shader学习整理/RenderFeature/PerObjectShadow/PerObjectShadow.hlsl"
    	

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
    		float _Anisotropy;
    		float _AOInt;
    	
            half4 _RimCol;
            float _RimWidth;
    	
            float4 _MainTex_ST;
    		
    		float _MatCapLerp;
    		float _Test;
            //----------变量声明结束-----------
            CBUFFER_END
    	
    		float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
			 {
			 return F0 + (max(float3(1 ,1, 1) * (1 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
			}
    	
			float3 FresnelLerp (half3 F0, half3 F90, half cosA)
			{
			    half t = Pow4 (1 - cosA);   // FAST WAY
			    return lerp (F0, F90, t);
			}

    		float3 UnpackScaleNormal(float4 packedNormal, float bumpScale)
            {
	            float3 normal = UnpackNormal(packedNormal);
            	normal.xy *= bumpScale;
            	normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));
            	return normal;
            }
            
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
            	float4 tDirWS : TEXCOORD4;
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
            	o.tDirWS = float4(normalize(TransformObjectToWorldDir(v.tangent.xyz)),v.tangent.w);
            	o.bDirWS = normalize(cross(o.nDirWS,o.tDirWS)*v.tangent.w);
            	o.color = v.color;
                return o;
            }
    		
			half3 CalculateBxDFResult(
			    float3 nDir, 
			    float3 lDir, 
			    float3 vDir, 
			    float3 tDir, 
			    float3 bDir, 
			    float anisotropy, 
			    half3 MainTex, 
			    half3 lightCol, 
			    float smoothness, 
			    float metallic,
			    float ao, 
			    half3 metalMatCap,
			    half3 satinMatCap,
			    float shadow, 
			    TEXTURE2D_PARAM(_RampTex,sampler_RampTex), 
			    float isAd)
			{
			    float3 hDir = normalize(vDir + lDir);

			    float NoL = max(saturate(dot(nDir, lDir)), 0.000001);
			    float NoV = max(saturate(dot(nDir, vDir)), 0.000001);
			    float HoV = max(saturate(dot(vDir, hDir)), 0.000001);
			    float HoL = max(saturate(dot(lDir, hDir)), 0.000001);
			    float NoH = max(saturate(dot(nDir, hDir)), 0.000001);
            	
            	float HoT_raw = dot(hDir, tDir);
			    float HoB_raw = dot(hDir, bDir);
            	
            	float VoT_raw = dot(vDir, tDir);
			    float VoB_raw = dot(vDir, bDir);
			    float NoV_raw = dot(vDir, nDir);
            	
            	float LoT_raw = dot(lDir, tDir);
			    float Lob_raw = dot(lDir, bDir);
			    float NoL_raw = dot(lDir, nDir);

			    //粗糙度一家
			    float perceptualRoughness = 1 - smoothness;
			    float roughness = perceptualRoughness * perceptualRoughness;
			    float squareRoughness = roughness * roughness;
            	
            	float lerpRoughness = lerp(0.002, 1.0, roughness);
            	float lerpSquareRougness = lerp(0.002, 1.0, squareRoughness);

			    //反照率
			    float3 Albedo = MainTex;

			    // ----------------------------
			    // 直接光镜面反射部分
			    // ----------------------------

			    // ---- GetAnisoAxes(roughness, anisotropy, ax, ay) ----
			    float anisoAbs = saturate(abs(anisotropy)); // 强度 [0,1]
			    float aspect = sqrt(max(1.0 - 0.9 * anisoAbs, 0.0001));

			    float ax = max(0.0001, lerpRoughness / aspect);
			    float ay = max(0.0001, lerpRoughness * aspect);

			    if (anisotropy < 0.0)
			    {
			        float tmp = ax;
			        ax = ay;
			        ay = tmp;
			    }

			    // ---- D_GGX_Aniso(N,T,B,H,ax,ay) ----
			    float ax2 = ax * ax;
			    float ay2 = ay * ay;
			    float denom = (HoT_raw * HoT_raw) / ax2 + (HoB_raw * HoB_raw) / ay2 + (NoH * NoH);
			    float D = 1.0 / (PI * ax * ay * denom * denom);

			    // ---- G_SmithGGX_Aniso(N,T,B,V,L,ax,ay) ----
			    // G1(V)
			    float G1V;
			    {
			        if (NoV_raw <= 0.0)
			        {
			            G1V = 0.0;
			        }
			        else
			        {
			            float NoV2 = max(NoV_raw * NoV_raw, 0.000001);
			            float t = ax2 * (VoT_raw * VoT_raw) + ay2 * (VoB_raw * VoB_raw);
			            float lambda = (sqrt(1.0 + t / NoV2) - 1.0) * 0.5;
			            G1V = 1.0 / (1.0 + lambda);
			        }
			    }

			    // G1(L)
			    float G1L;
			    {
			        if (NoL_raw <= 0.0)
			        {
			            G1L = 0.0;
			        }
			        else
			        {
			            float NoL2 = max(NoL_raw * NoL_raw, 0.000001);
			            float t = ax2 * (LoT_raw * LoT_raw) + ay2 * (Lob_raw * Lob_raw);
			            float lambda = (sqrt(1.0 + t / NoL2) - 1.0) * 0.5;
			            G1L = 1.0 / (1.0 + lambda);
			        }
			    }

			    float G = G1V * G1L;

			    // ---- Fresnel ----
			    float3 F0 = lerp(kDielectricSpec.rgb, Albedo, metallic);
			    float3 F  = F0 + (1 - F0) * pow((1 - HoV), 5);

			    float3 SpecularResult = (D * G * F) / (4 * NoV * NoL);
            	
			    half3 specRamp = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(NoL, 0.4)).rgb;
			    float3 specColor = SpecularResult * lightCol * specRamp * PI;

			    // ----------------------------
			    // 直接光漫反射部分
			    // ----------------------------
			    float kd = (1 - F) * (1 - metallic);
			    half3 shadowRamp = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(NoL, abs(isAd - 0.1))).rgb;
			    float3 diffColor = kd * Albedo * lightCol * shadowRamp;

			    float3 DirectLightResult = diffColor + specColor;

            	
            	
            	float3 IndirectResult = 0;
			    if (!isAd)
			    {
					// ----------------------------
				    // 间接光漫反射
				    // ----------------------------
				    half3 ambient_contrib = SampleSH(nDir);
				    float3 ambient = 0.03 * Albedo;
				    float3 iblDiffuse = max(half3(0, 0, 0), ambient.rgb + ambient_contrib);
				    float nDotv_Ramp = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(NoV, 0.6)).r;
				    float3 Flast = fresnelSchlickRoughness(max(nDotv_Ramp, 0.0), F0, roughness);
				    float kdLast = (1 - Flast) * (1 - metallic);
				    float3 iblDiffColor = iblDiffuse * kdLast * Albedo * lightCol;

				    // ----------------------------
				    // 间接光镜面反射
				    // ----------------------------
				    float mip_roughness = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);
				    float3 reflectVec = reflect(-vDir, nDir);
				    half mip = mip_roughness * UNITY_SPECCUBE_LOD_STEPS;
				    half4 rgbm = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectVec, mip);
				    float3 iblSpecular = DecodeHDREnvironment(rgbm, unity_SpecCube0_HDR);

				    float3 iblMatCap = lerp(satinMatCap, metalMatCap, metallic);
				    iblSpecular = lerp(iblSpecular, iblMatCap, _MatCapLerp);

				    float surfaceReduction = 1.0 / (lerpSquareRougness + 1.0);

				    float oneMinusReflectivity = 1 - max(max(SpecularResult.r, SpecularResult.g), SpecularResult.b);
				    float grazingTerm = saturate(smoothness + (1 - oneMinusReflectivity));
				    float3 iblSpecColor = iblSpecular * surfaceReduction * FresnelLerp(F0, grazingTerm, nDotv_Ramp) * lightCol;

				    IndirectResult = iblDiffColor + iblSpecColor;
			    }
            	

			    float3 result = DirectLightResult * shadow + IndirectResult * ao;
			    return result;
			}



    		float3 NormalBlendReoriented(float3 A, float3 B)
			{
				float3 t = A.xyz + float3(0.0, 0.0, 1.0);
				float3 u = B.xyz * float3(-1.0, -1.0, 1.0);
				return (t / t.z) * dot(t, u) - u;
			}
    		

            half4 frag (vertexOutput i) : SV_TARGET
            {
            	//MainTex
            	float2 mainTexUV = i.uv *_MainTex_ST.xy+_MainTex_ST.zw;
                half4 albedo = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,mainTexUV);
            	albedo.rgb *=_ColorTint.rgb; 
            	
            	//TBN Matrix & SampleNormalMap
            	float3x3 TBN = float3x3(i.tDirWS.xyz,i.bDirWS.xyz,i.nDirWS.xyz);
            	float2 normalUV = i.uv*_NormalMap_ST.xy+_NormalMap_ST.zw;
            	float4 packedNormal = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,normalUV);
            	float3 var_NormalMap = UnpackScaleNormal(packedNormal,_NormalInt);

				//Vector
				float3 nDirWS = normalize(mul(var_NormalMap,TBN));
            	float3 tDirWS = normalize(i.tDirWS - nDirWS * dot(i.tDirWS, nDirWS));
				float3 bDirWS = cross(nDirWS, tDirWS) * i.tDirWS.w;							
            	float3 nDirVS = TransformWorldToViewNormal(nDirWS);
            	float3 vDirWS = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
            	
            	// Metallic & Smoothness
            	
            	float metallic = _Metallic;
            	float smoothness = _Smoothness;
            	float anisotropy = _Anisotropy;
            	float ao = 1;
            	#ifdef _ENABLE_RMO_MAP
            	float4 RMOMap = SAMPLE_TEXTURE2D(_RMOMap,sampler_RMOMap,i.uv).rgba;
            	metallic = RMOMap.g*_Metallic;
            	smoothness = (1-RMOMap.r)*_Smoothness;
            	ao = lerp(1,RMOMap.b,_AOInt);
            	#endif
            	
            	//MatCap
            	float2 matCapUV = nDirVS.xy*0.5 + 0.5;
            	half3 metalMatCap = SAMPLE_TEXTURE2D(_MetalMatCap,sampler_MetalMatCap,matCapUV);
            	half3 satinMatCap = SAMPLE_TEXTURE2D(_SatinMatCap,sampler_SatinMatCap,matCapUV);
            	
            	//shadowCoord 逐像素计算，避免出现级联阴影过度时出现锯齿错误
            	float4 shadowCoord = TransformWorldToShadowCoord(i.posWS);
            	
            	//MainLight
            	Light mainLight = GetMainLight(shadowCoord);
                half3 mainLightColor = mainLight.color;
            	float3 mainLightDir = mainLight.direction;
            	float mainLightShadow = MainLightRealtimeShadow(shadowCoord);
            	float perObjectShaodw = ComputePerObjectShadow(i.posWS, nDirWS);
            	mainLightShadow = mainLightShadow*perObjectShaodw;
            	float3 mainLightRadiance = mainLightColor * mainLight.distanceAttenuation;
            	half3 mainColor = CalculateBxDFResult(nDirWS,mainLightDir,vDirWS,tDirWS,bDirWS,anisotropy,albedo.rgb,mainLightRadiance,smoothness,metallic,ao,metalMatCap,satinMatCap,mainLightShadow,TEXTURE2D_ARGS(_RampTex,sampler_RampTex),0);

            	//AditionalLight
            	uint lightCount = GetAdditionalLightsCount();
            	half3 additionalColor = half3(0,0,0);
				for (uint lightIndex = 0; lightIndex < lightCount; lightIndex++)
				{
				    Light additionalLight = GetAdditionalLight(lightIndex, i.posWS.xyz, 1);
					half3 additionalLightColor = additionalLight.color;
					float3 additionalLightDir = additionalLight.direction;
					// 光照衰减和阴影系数
                    float3 additionalLightRadiance = additionalLightColor * additionalLight.distanceAttenuation;
				    additionalColor += CalculateBxDFResult(nDirWS,additionalLightDir,vDirWS,tDirWS,bDirWS,anisotropy,albedo.rgb,additionalLightRadiance,smoothness,metallic,ao,metalMatCap,satinMatCap,additionalLight.shadowAttenuation,TEXTURE2D_ARGS(_RampTex,sampler_RampTex),1);
				}
            	
            	half3 MainFinalRGB = mainColor+additionalColor;

            	half3 FinalRGB = MainFinalRGB;
            	
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

        //Outline
        pass
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            Cull Front
            Lighting Off
            HLSLPROGRAM

            #pragma vertex vertOutline
            #pragma fragment fragOutline
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _OutlineColor;
            float _OutlineWidth;
            //----------变量声明结束-----------
            CBUFFER_END

            struct vertexInputOutline
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 color : COLOR;
            };

            struct vertexOutputOutline
            {
                
                float4 pos : SV_POSITION;
            };

            vertexOutputOutline vertOutline (vertexInputOutline v)
            {
                vertexOutputOutline o;

                float3 outline_normal = v.color*2.0-1.0;
                float4 clipPos = TransformObjectToHClip(v.vertex.xyz+outline_normal*0.01*_OutlineWidth*v.color.a);
                o.pos = clipPos;
                return o;
            }

            half4 fragOutline (vertexOutputOutline i) : SV_TARGET
            {
                return _OutlineColor;
            }
            
            ENDHLSL
        }
		
    }
}