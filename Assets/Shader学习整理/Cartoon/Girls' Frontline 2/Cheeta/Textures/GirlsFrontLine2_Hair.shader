Shader "URP/NPR/GirlsFrontLine2/Hair"
{
    Properties
    {
    	[Header(Main Layer)]
    	_MainTex("Main Texture",2D) = "white"{}
    	
    	[Header(PBR)]
        _ColorTint("Color Tint",Color) = (1.0,1.0,1.0,1.0)
    	_Smoothness("Smoothness",Range(0,1)) = 0
    	_Metallic("Metallic",Range(0,1)) = 0
    	
    	[Header(Normal)]
    	_NormalMap("Normal Map",2D) = "bump"{}
    	_NormalInt("Normal Intensity",Range(0,5)) = 1
	    
    	[Header(Ramp)]
    	_RampTex("Ramp Texture",2D) = "white"{}
	    
    	[Header(Hair)]
    	_SpecTint("Color Tint",Color) = (1.0,1.0,1.0,1.0)
    	_SpecMask("Hair Specular Mask",2D) = "black"{}
    	_AnisotropicSize("Anisotropic Size",Range(0,1)) = 1
    	_AnisotropicOffset("Anisotropic Offset",Range(-1,1)) = 0
    	
    	[Header(PerObjectShadow)]
        [IntRange]_Unit("Unit",Range(1,10)) = 1
	    
    	[Header(Outline)]
        _OutlineColor("Outline Color",Color) = (0.0,0.0,0.0,0.0)
        _OutlineWidth("Outline Width",Range(0,5)) = 1
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
    	
    		#define kDielectricSpec half4(0.06, 0.06, 0.06, 1.0 - 0.06)
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);//定义贴图
            SAMPLER(sampler_MainTex);//定义采样器
    		TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
    		TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
    		TEXTURE2D(_RampTex);
            SAMPLER(sampler_RampTex);
    		
    		TEXTURE2D(_SpecMask);
    		SAMPLER(sampler_SpecMask);
    		
    		
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _ColorTint;

    		float _NormalInt;
    		float4 _NormalMap_ST;
            
            float _Smoothness;
            float _Metallic;
    	
            half4 _RimCol;
            float _RimWidth;
    	
            float4 _MainTex_ST;
    		
    		float _SDFSmoothness;
    		float4 _SDF_ST;
    		
    		float _AnisotropicSize;
    		float _AnisotropicOffset;
    		
    		half4 _SpecTint;
    		float4 _SpecMask_ST;
    		
    		
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
            	float2 uv1 : TEXCOORD1;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            	float2 uv1 : TEXCOORD1;
                float3 nDirWS : TEXCOORD2;
                float3 posWS : TEXCOORD3;
            	float4 screenPos : TEXCOORD4;
            	float3 tDirWS : TEXCOORD5;
            	float3 bDirWS : TEXCOORD6;
            	float4 color : TEXCOORD7;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
            	float4 posCS = TransformObjectToHClip(v.vertex.xyz);
                o.pos = posCS;
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
            	o.uv1 = v.uv1;
                o.posWS = TransformObjectToWorld(v.vertex);
            	o.screenPos = ComputeScreenPos(posCS);
            	o.tDirWS = normalize(TransformObjectToWorld(v.tangent));
            	o.bDirWS = normalize(cross(o.nDirWS,o.tDirWS)*v.tangent.w);
            	o.color = v.color;
                return o;
            }
    		
    		half3 CalculateBxDFResult(
    			float3 nDir, 
    			float3 lDir, 
    			float3 vDir, 
    			half3 MainTex, 
    			half3 lightCol, 
    			float smoothness, 
    			float metallic,
    			float3 specularMask,
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
            	float lerpSquareRoughness = pow(lerp(0.002,1,roughness),2);//Unity把roughness lerp到了0.002,目的是保证在smoothness为0表面完全光滑时也会留有一点点高光
            	//反照率
            	float3 Albedo = MainTex;
            	
            	//RampTex 
            	//第一行(0.75-1): additional light shadowRamp
            	//第二行(0.5-0.75): metal env blinnphong specularRamp(存疑)
            	//第三行(0.25-0.5): direct/additional light specularRamp
            	//第四行(0-0.25): direct light shadowRamp
            	
				//直接光镜面反射部分
            	
				//菲涅尔方程
				float3 F0 = lerp(kDielectricSpec.rgb, Albedo, metallic);//使用Unity内置函数计算平面基础反射率
				float3 F = F0 + (1 - F0) *pow((1-hDotv),5);
            	
            	//因为之前少给漫反射除了一个PI，为保证漫反射和镜面反射比例所以多乘一个PI
            	float shininess = 2.0 / lerpSquareRoughness - 2.0;
            	float normalizedBlinnPhong = (shininess+8.0)/(8.0*PI) * pow(nDoth,shininess);
            	float3 SpecularResult = normalizedBlinnPhong;
            	half3 specRamp = SAMPLE_TEXTURE2D(_RampTex,sampler_RampTex,float2(normalizedBlinnPhong,0.4)).rgb;
            	float3 specColor = specRamp * lightCol * nDotl * PI * F;
            	
            	
				//直接光漫反射部分
				//漫反射系数
				float kd = (1-F)*(1-metallic);
            	half3 shadowRamp = SAMPLE_TEXTURE2D(_RampTex,sampler_RampTex,float2(nDotl,abs(isAd-0.1))).rgb;
				float3 diffColor = kd*Albedo*lightCol*shadowRamp;//此处为了达到和Unity相近的渲染效果也不去除这个PI
            	
            	//直接光结果
            	float3 DirectLightResult = diffColor + specColor*specularMask;

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
            		
					float surfaceReduction = 1.0 / (roughness*roughness + 1.0); //Liner空间
					//float surfaceReduction = 1.0 - 0.28*roughness*perceptualRoughness; //Gamma空间

					float oneMinusReflectivity = 1 - max(max(SpecularResult.r, SpecularResult.g), SpecularResult.b);
					float grazingTerm = saturate(smoothness + (1 - oneMinusReflectivity));
            		float3 iblSpecColor =  iblSpecular * surfaceReduction * FresnelLerp(F0, grazingTerm, nDotv_Ramp);
            		
            		//间接光结果
					IndirectResult = iblDiffColor + iblSpecColor*specularMask;
				}
            	
				
            	
            	float3 result= DirectLightResult*shadow + IndirectResult;
            	
            	return  result;
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
            	
            	//Specular Texture
            	float anisotropicOffsetV = -vDirWS.y* _AnisotropicSize+ _AnisotropicOffset;
            	float2 specMaskUV = (i.uv1+float2(0,anisotropicOffsetV))*_SpecMask_ST.xy+_SpecMask_ST.zw;
            	float3 specularMask = SAMPLE_TEXTURE2D(_SpecMask,sampler_SpecMask,specMaskUV).r * _SpecTint.rgb;
            	
            	//shadowCoord 逐像素计算，避免出现级联阴影过度时出现锯齿错误
            	float4 shadowCoord = TransformWorldToShadowCoord(i.posWS);
            	
            	//MainLight
            	Light mainLight = GetMainLight(shadowCoord);
                half3 mainLightColor = mainLight.color;
            	float3 mainLightDir = mainLight.direction;
            	float mainLightShadow = MainLightRealtimeShadow(shadowCoord);
            	float perObjectShaodw = ComputePerObjectShadow(i.posWS, nDirWS);
            	mainLightShadow = perObjectShaodw*mainLightShadow;
            	float3 mainLightRadiance = mainLightColor * mainLight.distanceAttenuation;
            	half3 mainColor = CalculateBxDFResult(nDirWS,mainLightDir,vDirWS,albedo.rgb,mainLightRadiance,smoothness,metallic,specularMask,mainLightShadow,TEXTURE2D_ARGS(_RampTex,sampler_RampTex),0);

            	//AditionalLight
            	uint lightCount = GetAdditionalLightsCount();
            	half3 additionalColor = half3(0,0,0);
				for (uint lightIndex = 0; lightIndex < lightCount; lightIndex++)
				{
				    Light additionalLight = GetAdditionalLight(lightIndex, i.posWS.xyz, 1);
					half3 additionalLightColor = additionalLight.color;
					float3 additionalLightDir = additionalLight.direction;
					float additionaLightShadow = additionalLight.shadowAttenuation;
                    float3 additionalLightRadiance = additionalLightColor * additionalLight.distanceAttenuation;
				    additionalColor += CalculateBxDFResult(nDirWS,additionalLightDir,vDirWS,albedo.rgb,additionalLightRadiance,smoothness,metallic,specularMask,additionaLightShadow,TEXTURE2D_ARGS(_RampTex,sampler_RampTex),1);
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

		//刘海深度渲染
	    pass
        {
        	Name "HairDepthOnly"
            Tags
            {
                "LightMode" = "HairDepthOnly"
            }
	        
            ZWrite On
            ColorMask R
            Cull Off
            HLSLPROGRAM
            #pragma target 3.5

            #pragma vertex vert
            #pragma fragment frag_DepthOnly

            half4 frag_DepthOnly(vertexOutput i) : SV_TARGET
			{
				return i.pos.z;
			}
            
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