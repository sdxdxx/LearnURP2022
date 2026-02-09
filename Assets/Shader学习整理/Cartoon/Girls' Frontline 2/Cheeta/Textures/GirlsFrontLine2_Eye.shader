Shader "URP/NPR/GirlsFrontLine2/Eye"
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
    	
    	[Header(PerObjectShadow)]
        [IntRange]_Unit("Unit",Range(1,10)) = 1
	    
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
    		
    		half3 CalculatePBRResult(
    			float3 nDir, 
    			float3 lDir, 
    			float3 vDir, 
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
				float3 hDir = normalize(vDir+lDir);

				float nDotl = max(saturate(dot(nDir,lDir)),0.000001);
				float nDotv = max(saturate(dot(nDir,vDir)),0.000001);
				float hDotv = max(saturate(dot(vDir,hDir)),0.000001);
				float hDotl = max(saturate(dot(lDir,hDir)),0.000001);
				float nDoth = max(saturate(dot(nDir,hDir)),0.000001);
            	
				//粗糙度一家
				float perceptualRoughness = 1 - smoothness;//粗糙度
				float roughness = perceptualRoughness * perceptualRoughness;//粗糙度二次方
				float squareRoughness = roughness * roughness;//粗糙度四次方
            	
            	//反照率
            	float3 Albedo = MainTex;
            	
            	//RampTex 
            	//第一行(0.75-1): additional light shadowRamp
            	//第二行(0.5-0.75): metal env blinnphong specularRamp(存疑)
            	//第三行(0.25-0.5): direct/additional light specularRamp
            	//第四行(0-0.25): direct light shadowRamp

				//直接光镜面反射部分

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
				float3 F0 = lerp(kDielectricSpec.rgb, Albedo, metallic);//使用Unity内置函数计算平面基础反射率
				float3 F = F0 + (1 - F0) *pow((1-hDotv),5);
            	float3 SpecularResult = (D*G*F)/(4*nDotv*nDotl);

				//因为之前少给漫反射除了一个PI，为保证漫反射和镜面反射比例所以多乘一个PI
            	half3 specRamp = SAMPLE_TEXTURE2D(_RampTex,sampler_RampTex,float2(nDotl,0.4)).rgb;
				float3 specColor = SpecularResult * lightCol * specRamp * PI;
				 
				//直接光漫反射部分
				//漫反射系数
				float kd = (1-F)*(1-metallic);
            	half3 shadowRamp = SAMPLE_TEXTURE2D(_RampTex,sampler_RampTex,float2(nDotl,abs(isAd-0.1))).rgb;
				float3 diffColor = kd*Albedo*lightCol*shadowRamp;//此处为了达到和Unity相近的渲染效果也不去除这个PI
            	
            	//直接光结果
            	float3 DirectLightResult = diffColor + specColor;

            	
            	float3 IndirectResult = 0;

				if (!isAd)
				{
					//间接光漫反射
					half3 ambient_contrib = SampleSH(nDir);//反射探针接收
					float3 ambient = 0.03 * Albedo;
					float3 iblDiffuse = max(half3(0, 0, 0), ambient.rgb + ambient_contrib);
            		float nDotv_Ramp = SAMPLE_TEXTURE2D(_RampTex,sampler_RampTex,float2(nDotv,0.6)).r;
					float3 Flast = fresnelSchlickRoughness(max(nDotv_Ramp, 0.0), F0, roughness);
            		float kdLast = (1 - Flast) * (1 - metallic);
            		float3 iblDiffColor = iblDiffuse * kdLast * Albedo * lightCol;
            		
					//间接光镜面反射
					float mip_roughness = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);
					float3 reflectVec = reflect(-vDir, nDir);
					half mip = mip_roughness * UNITY_SPECCUBE_LOD_STEPS;
					half4 rgbm =  SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0,samplerunity_SpecCube0, reflectVec, mip);
					float3 iblSpecular = DecodeHDREnvironment(rgbm, unity_SpecCube0_HDR);
            		
            		//ibl Specular MatCap
            		float3 iblMatCap = lerp(satinMatCap,metalMatCap,metallic);
            		iblSpecular = lerp(iblSpecular,iblMatCap,_MatCapLerp);
            		
					float surfaceReduction = 1.0 / (roughness*roughness + 1.0); //Liner空间
					//float surfaceReduction = 1.0 - 0.28*roughness*perceptualRoughness; //Gamma空间

					float oneMinusReflectivity = 1 - max(max(SpecularResult.r, SpecularResult.g), SpecularResult.b);
					float grazingTerm = saturate(smoothness + (1 - oneMinusReflectivity));
            		float3 iblSpecColor =  iblSpecular * surfaceReduction * FresnelLerp(F0, grazingTerm, nDotv_Ramp) * lightCol;
            		
            		//间接光结果
					IndirectResult = iblDiffColor + iblSpecColor;
				}
            	
            	float3 result_RBR = DirectLightResult*shadow + IndirectResult*ao;

            	return  result_RBR;
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
				 float3x3 TBN = float3x3(i.tDirWS,i.bDirWS,i.nDirWS);
            	float2 normalUV = i.uv*_NormalMap_ST.xy+_NormalMap_ST.zw;
            	float4 packedNormal = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,normalUV);
            	float3 var_NormalMap = UnpackScaleNormal(packedNormal,_NormalInt);

				//Vector
				float3 nDirWS = normalize(mul(var_NormalMap,TBN));
            	float3 nDirVS = TransformWorldToViewNormal(nDirWS);
            	float3 vDirWS = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
            	
            	// Metallic & Smoothness
            	
            	float metallic = _Metallic;
            	float smoothness = _Smoothness;
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
            	mainLightShadow = perObjectShaodw*mainLightShadow;
            	mainLightShadow = lerp(0.75,1,mainLightShadow);
            	float3 mainLightRadiance = mainLightColor * mainLight.distanceAttenuation;
            	half3 mainColor = CalculatePBRResult(nDirWS,mainLightDir,vDirWS,albedo.rgb,mainLightRadiance,smoothness,metallic,ao,metalMatCap,satinMatCap,mainLightShadow,TEXTURE2D_ARGS(_RampTex,sampler_RampTex),0);

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
				    additionalColor += CalculatePBRResult(nDirWS,additionalLightDir,vDirWS,albedo.rgb,additionalLightRadiance,smoothness,metallic,ao,metalMatCap,satinMatCap,additionalLight.shadowAttenuation,TEXTURE2D_ARGS(_RampTex,sampler_RampTex),1);
				}
            	
            	half3 MainFinalRGB = mainColor+additionalColor;

            	half3 FinalRGB = MainFinalRGB;
            	
                return half4(FinalRGB,1.0);
            }
    	ENDHLSL

        pass
        {
	        Tags{"LightMode"="UniversalForward"}
            Blend [_BlendSrc] [_BlendDst]
			Cull  [_CullMode]
             
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