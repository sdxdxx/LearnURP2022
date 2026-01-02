Shader "URP/SSS/Jade"
{
    Properties
    {
    	[Header(Main Layer)]
    	_MainTex("Main Texture",2D) = "white"{}
    	
    	[Header(SSS)]
    	_ThicknessMap("Thickness Map",2D) = "white"{}
    	_SSSRange("Subsurface Scattering Range",Range(0,1)) = 1
    	_NormalDistortion("Normal Distortion",Range(0,1)) = 0.5
    	_ScatterDistance("Scatter Distance(RGB)",Color) = (0.45, 1.0, 0.6)
    	_MaxSampleDistanceScale("Max Sample Distance Scale",Float) = 0.05
    	[Toggle(_ENABLE_TEST)]_EnableTest("Enable Test",Float) = 0
    	
    	[Header(PBR)]
        _ColorTint("Color Tint",Color) = (1.0,1.0,1.0,1.0)
    	_MetallicSmoothnessTex("Metallic Smoothness Texture",2D) = "white"{}
    	_Smoothness("Smoothness",Range(0,1)) = 0
    	_Metallic("Metallic",Range(0,1)) = 0
    	
    	[Header(Normal)]
    	_NormalMap("Normal Map",2D) = "bump"{}
    	_NormalInt("Normal Intensity",Range(0,5)) = 1
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
    	

    		#pragma multi_compile  _MAIN_LIGHT_SHADOWS
    		#pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
    		#pragma multi_compile  _SHADOWS_SOFT
    		
    		#pragma shader_feature_local _ENABLE_TEST
    	
    		#define kDielectricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04)
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);//定义贴图
            SAMPLER(sampler_MainTex);//定义采样器
    		TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
    		TEXTURE2D(_MetallicSmoothnessTex);
            SAMPLER(sampler_MetallicSmoothnessTex);
    		TEXTURE2D(_ThicknessMap);
    		SAMPLER(sampler_ThicknessMap);
    		
    		TEXTURE2D(_CameraDepthTexture);
    		TEXTURE2D(_DiffuseBRDF);
    		TEXTURE2D(_SSSMask);
    		
    	
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _ColorTint;
    		
    		float4 _ThicknessMap_ST;
			float _SSSRange;
    		float _NormalDistortion;
    		half3 _ScatterDistance;
    		float _MaxSampleDistanceScale;
    		
    		float _NormalInt;
    		float4 _NormalMap_ST;
            
            float _Smoothness;
            float _Metallic;
    	
            half4 _RimCol;
            float _RimWidth;
    	
            float4 _MainTex_ST;
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

    		half3 CalculateDiffuseBRDFResult(float3 nDir, float3 lDir, float3 vDir, half3 MainTex, half3 lightCol, float smoothness, float metallic, float thickness, float normalDistortion, float sssRange, float shadow)
			{
			    float3 hDir = normalize(vDir + lDir);

			    float nDotl = max(saturate(dot(nDir, lDir)), 0.000001);
			    float nDotv = max(saturate(dot(nDir, vDir)), 0.000001);
			    float hDotv = max(saturate(dot(vDir, hDir)), 0.000001);

			    // --- 粗糙度与基础参数 ---
			    float perceptualRoughness = 1 - smoothness;
			    float roughness = perceptualRoughness * perceptualRoughness;

			    float3 Albedo = MainTex;
			    
			    // --- 菲涅尔系数 ---
			    float3 F0 = lerp(kDielectricSpec.rgb, Albedo, metallic);
			    float3 F = F0 + (1 - F0) * pow((1 - hDotv), 5);

			    // --- 1. 直接光漫反射 (Direct Diffuse) ---
			    // 能量守恒：剔除掉金属度(metallic)和被镜面反射(F)拿走的能量
			    float kd = (1 - F) * (1 - metallic);
			    // 注意：未除以 PI (以此匹配 Unity 默认光照强度)
			    float3 diffColor = kd * Albedo * lightCol * nDotl; 

			    // --- 2. 间接光漫反射 (Indirect Diffuse / SH) ---
			    // 采样球谐光照 (Light Probe / Ambient)
			    half3 ambient_contrib = SampleSH(nDir);
			    float3 ambient = 0.03 * Albedo;
			    float3 iblDiffuseRaw = max(half3(0, 0, 0), ambient.rgb + ambient_contrib);
			    
			    // 计算间接光的菲涅尔和 Kd
			    float3 Flast = fresnelSchlickRoughness(max(nDotv, 0.0), F0, roughness);
			    float kdLast = (1 - Flast) * (1 - metallic);
			    
			    float3 indirectDiffuseResult = iblDiffuseRaw * kdLast * Albedo;

			    // --- 3. SSS 透射项 (Transmission) ---
			    // 这是光线从背面穿透过来的颜色，必须加在这里一起参与后续的 SSS 模糊
			    float3 SSS = saturate(pow(max(0, dot(vDir, -normalize(lDir + nDir * normalDistortion))), 1 / (sssRange + 0.01))) * (1 - thickness) * Albedo * lightCol; 

			    // --- 最终合并 ---
			    // 逻辑：(直接漫反射 * 阴影) + 间接漫反射 + 透射
			    float3 result_DiffuseOnly = diffColor*shadow + indirectDiffuseResult + SSS;

			    return result_DiffuseOnly;
			}
    		
			// -----------------------------------------------------------------------------
			// Burley Normalized Diffusion Core Function (Final Fixed)
			// -----------------------------------------------------------------------------

			// 泊松圆盘螺旋采样点 (16 samples)
			static const int SAMPLE_COUNT = 16;
			static const float2 s_Samples[16] = {
			    float2(-0.613392, 0.617481), float2(0.170019, -0.040254),
			    float2(-0.299417, 0.791925), float2(0.645680, 0.493210),
			    float2(-0.651784, 0.717887), float2(0.421003, 0.027070),
			    float2(-0.817194, -0.271096), float2(-0.705374, -0.668203),
			    float2(0.977050, -0.108615), float2(0.063326, 0.142369),
			    float2(0.203528, 0.214331), float2(-0.667531, 0.326090),
			    float2(-0.098422, -0.295755), float2(-0.885922, 0.215369),
			    float2(0.566637, 0.605213), float2(0.039766, -0.396100)
			};

			half3 CalculateBurleyNormalizedSSSResult(
			    TEXTURE2D_PARAM(diffuseTex, sampler_diffuse), 
			    TEXTURE2D_PARAM(depthTex,   sampler_depth),   
			    float2 uv,
			    float3 scatterDistance,  // 物理参数 d (RGB)
			    float  maxDistanceScale, // 世界空间最大模糊半径 (米)
			    float  maskValue         // SSS 强度 Mask (0-1)
			)
			{
				
				
			    // 0. 性能优化：Mask 过小直接返回原图
			    if (maskValue < 0.001)
			        return SAMPLE_TEXTURE2D(diffuseTex, sampler_diffuse, uv).rgb;

			    // 1. 获取中心像素数据
			    half3 centerColor = SAMPLE_TEXTURE2D(diffuseTex, sampler_diffuse, uv).rgb;
			    // 获取线性深度 (米)
			    float centerDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(depthTex, sampler_depth, uv), _ZBufferParams);

			    // 2. 屏幕空间步长计算 (透视投影修正)
			    // 这一步非常关键：它将世界空间的“1米”换算成屏幕上的 UV 长度
			    // unity_CameraProjection[1][1] 对应 cot(FOV/2)，用于处理视场角影响
			    // 如果你在 Scene 视图看起来不对，确保 Game 视图的 FOV 是正常的
			    float distanceScale = maxDistanceScale * maskValue;
			    float2 worldToScreenScale = (unity_CameraProjection[1][1] / centerDepth) * distanceScale;
			    
			    // 修正屏幕长宽比 (Aspect Ratio)，确保模糊是圆形的而不是椭圆的
			    worldToScreenScale.x /= _ScreenParams.x / _ScreenParams.y;

			    // 初始化累加器
			    half3 totalWeight = 0;
			    half3 totalColor = 0;

			    // ---------------------------------------------------------------------
			    // 【关键修正】: 动态计算中心像素的 r
			    // ---------------------------------------------------------------------
			    // 之前的问题：r 写死为 0.0001，导致 1/r 极大，中心权重淹没周围。
			    // 现在的逻辑：假设中心像素代表半径为 "最大范围的 5%" 的一个圆盘区域。
			    // 这样能保证中心权重与周围采样点的权重在同一个数量级 (Magnitude)。
			    float center_r = max(distanceScale * 0.05, 0.0001); 
			    
			    // 计算中心点的 Burley 权重
			    float3 center_d_val = max(scatterDistance, 0.001);
			    float3 center_r_over_d = center_r / center_d_val;
			    // Burley Profile: (e^-x + e^-x/3) / r
			    float3 center_numer = exp(-center_r_over_d) + exp(-center_r_over_d / 3.0);
			    // 注意：公式中分母含有 d * r
			    float3 center_denom = center_d_val * center_r; 
			    float3 centerWeight = center_numer / max(center_denom, 0.00001);
				
			    // 累加中心点
			    totalColor += centerColor * centerWeight;
			    totalWeight += centerWeight;

			    // ---------------------------------------------------------------------
			    // 循环采样 (Disk Sampling)
			    // ---------------------------------------------------------------------
			    [unroll]
			    for (int i = 0; i < SAMPLE_COUNT; i++)
			    {
			        float2 offset = s_Samples[i];
			        
			        // 计算采样点 UV
			        float2 sampleUV = uv + offset * worldToScreenScale;

			        // 读取采样点
			        half3 sampleColor = SAMPLE_TEXTURE2D(diffuseTex, sampler_diffuse, sampleUV).rgb;
			        float sampleDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(depthTex, sampler_depth, sampleUV), _ZBufferParams);

			        // 计算物理距离 r (World Space Distance)
			        // 平面距离：offset长度 * 最大半径
			        float planeDist = length(offset * distanceScale);
			        
			        // 深度距离惩罚 (Bilateral Weight)
			        // 增加倍率 (20) 以锐化边缘，防止背景颜色漏到前景
			        float depthDist = abs(centerDepth - sampleDepth) * 20; 
			        
			        // 综合距离 r
			        float r = sqrt(planeDist * planeDist + depthDist * depthDist);
			        // 加上 center_r 是为了防止 offset=0 的极端情况，并平滑中心区域
			        r = max(r, center_r); 

			        // ---------------------------------------------------------------------
			        // Burley Profile 权重计算
			        // ---------------------------------------------------------------------
			        float3 d_val = max(scatterDistance, 0.001);
			        float3 r_over_d = r / d_val;
			        
			        float3 numer = exp(-r_over_d) + exp(-r_over_d / 3.0);
			        float3 denom = d_val * r;
			        
			        float3 weight = numer / max(denom, 0.00001);

			        totalColor += sampleColor * weight;
			        totalWeight += weight;
			    }

			    // 归一化
			    return totalColor / max(totalWeight, 0.0001);
			}
    		
    		half3 CalculatePBRResult(float3 nDir, float3 lDir, float3 vDir, half3 MainTex, half3 lightCol, float smoothness, float metallic, float shadow)
            {
				float3 hDir = normalize(vDir+lDir);

				float nDotl = max(saturate(dot(nDir,lDir)),0.000001);
				float nDotv = max(saturate(dot(nDir,vDir)),0.000001);
				float hDotv = max(saturate(dot(vDir,hDir)),0.000001);
            	
				//粗糙度一家
				float perceptualRoughness = 1 - smoothness;//粗糙度
				float roughness = perceptualRoughness * perceptualRoughness;//粗糙度二次方
				float squareRoughness = roughness * roughness;//粗糙度四次方

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

				float3 Albedo = MainTex;
            	
				//菲涅尔方程
				float3 F0 = lerp(kDielectricSpec.rgb, Albedo, metallic);//使用Unity内置函数计算平面基础反射率
				float3 F = F0 + (1 - F0) *pow((1-hDotv),5);
				
            	float3 SpecularResult = (D*G*F)/(4*nDotv*nDotl);

				//因为少给漫反射除了一个PI，为保证漫反射和镜面反射比例所以多乘一个PI
				float3 directSpec = SpecularResult * lightCol * nDotl * PI;
				
				//间接光镜面反射
				float mip_roughness = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);
				float3 reflectVec = reflect(-vDir, nDir);

				half mip = mip_roughness * UNITY_SPECCUBE_LOD_STEPS;
				half4 rgbm =  SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0,samplerunity_SpecCube0, reflectVec, mip);

				float3 iblSpecular = DecodeHDREnvironment(rgbm, unity_SpecCube0_HDR);

				float surfaceReduction = 1.0 / (roughness*roughness + 1.0); //Liner空间
				//float surfaceReduction = 1.0 - 0.28*roughness*perceptualRoughness; //Gamma空间

				float oneMinusReflectivity = 1 - max(max(SpecularResult.r, SpecularResult.g), SpecularResult.b);
            	oneMinusReflectivity = oneMinusReflectivity * (1.0 - metallic);//修改
				float grazingTerm = saturate(smoothness + (1 - oneMinusReflectivity));
				float3 indirectSpec = float3(iblSpecular * surfaceReduction * FresnelLerp(F0, grazingTerm, nDotv));
				
				float3 spec = directSpec*shadow + indirectSpec;
				
            	float3 result_RBR = spec;

            	return result_RBR;
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
            	
            	//ThicknessMap
            	float thickness = SAMPLE_TEXTURE2D(_ThicknessMap,sampler_ThicknessMap, i.uv).r;
            	
            	//SSS + Direct Diffuse
            	float2 screenPos = i.screenPos.xy/i.screenPos.w;
            	float sssMask = SAMPLE_TEXTURE2D(_SSSMask,sampler_PointClamp, screenPos).r;
            	float3 burleyNormalizedSSSResult = CalculateBurleyNormalizedSSSResult(TEXTURE2D_ARGS(_DiffuseBRDF,sampler_LinearClamp),TEXTURE2D_ARGS(_CameraDepthTexture,sampler_PointClamp),screenPos,_ScatterDistance,_MaxSampleDistanceScale,sssMask);
            	
            	//TBN Matrix & SampleNormalMap
				 float3x3 TBN = float3x3(i.tDirWS,i.bDirWS,i.nDirWS);
            	float2 normalUV = i.uv*_NormalMap_ST.xy+_NormalMap_ST.zw;
            	float4 packedNormal = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,normalUV);
            	float3 var_NormalMap = UnpackScaleNormal(packedNormal,_NormalInt);

				//Vector
				float3 nDir = normalize(mul(var_NormalMap,TBN));
            	float3 vDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
            	
            	// Metallic & Smoothness
            	float4 MetallicSmoothnessTex = SAMPLE_TEXTURE2D(_MetallicSmoothnessTex,sampler_MetallicSmoothnessTex,i.uv).rgba;
            	float metallic = MetallicSmoothnessTex.r*_Metallic;
            	float smoothness = MetallicSmoothnessTex.a*_Smoothness;

            	//shadowCoord 逐像素计算，避免出现级联阴影过度时出现锯齿错误
            	float4 shadowCoord = TransformWorldToShadowCoord(i.posWS);
            	
            	//MainLight
            	Light mainLight = GetMainLight(shadowCoord);
                half3 mainLightColor = mainLight.color;
            	float3 mainLightDir = mainLight.direction;
            	float mainLightShadow = MainLightRealtimeShadow(shadowCoord);
            	float3 mainLightRadiance = mainLightColor * mainLight.distanceAttenuation;
            	half3 mainColor = CalculatePBRResult(nDir,mainLightDir,vDir,albedo.rgb,mainLightRadiance,smoothness,metallic,mainLightShadow);

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
				    additionalColor += CalculatePBRResult(nDir,additionalLightDir,vDir,albedo.rgb,additionalLightRadiance,smoothness,metallic,additionalLight.shadowAttenuation);
				}
            	
            	//Direct Diffuse + IBL Diffuse + SSS Transmission + SpecColor
            	
            	#ifdef _ENABLE_TEST
            	burleyNormalizedSSSResult = SAMPLE_TEXTURE2D(_DiffuseBRDF,sampler_LinearClamp,screenPos).rgb;
            	#endif
            	
            	half3 MainFinalRGB = mainColor+additionalColor+burleyNormalizedSSSResult;
            	
            	half3 FinalRGB = MainFinalRGB;
            	
                return half4(FinalRGB,1.0);
            }
    		
    		half4 frag_diffuse (vertexOutput i) : SV_TARGET
            {
            	//MainTex
            	float2 mainTexUV = i.uv *_MainTex_ST.xy+_MainTex_ST.zw;
                half4 albedo = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,mainTexUV);
            	albedo.rgb *=_ColorTint.rgb; 
            	
            	//ThicknessMap
            	float thickness = SAMPLE_TEXTURE2D(_ThicknessMap,sampler_ThicknessMap, i.uv).r;
            	
            	//TBN Matrix & SampleNormalMap
				 float3x3 TBN = float3x3(i.tDirWS,i.bDirWS,i.nDirWS);
            	float2 normalUV = i.uv*_NormalMap_ST.xy+_NormalMap_ST.zw;
            	float4 packedNormal = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,normalUV);
            	float3 var_NormalMap = UnpackScaleNormal(packedNormal,_NormalInt);

				//Vector
				float3 nDir = normalize(mul(var_NormalMap,TBN));
            	float3 vDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
            	
            	// Metallic & Smoothness
            	float4 MetallicSmoothnessTex = SAMPLE_TEXTURE2D(_MetallicSmoothnessTex,sampler_MetallicSmoothnessTex,i.uv).rgba;
            	float metallic = MetallicSmoothnessTex.r*_Metallic;
            	float smoothness = MetallicSmoothnessTex.a*_Smoothness;

            	//shadowCoord 逐像素计算，避免出现级联阴影过度时出现锯齿错误
            	float4 shadowCoord = TransformWorldToShadowCoord(i.posWS);
            	
            	//MainLight
            	Light mainLight = GetMainLight(shadowCoord);
                half3 mainLightColor = mainLight.color;
            	float3 mainLightDir = mainLight.direction;
            	float mainLightShadow = MainLightRealtimeShadow(shadowCoord);
            	float3 mainLightRadiance = mainLightColor * mainLight.distanceAttenuation;
            	half3 mainColor = CalculateDiffuseBRDFResult(nDir,mainLightDir,vDir,albedo.rgb,mainLightRadiance,smoothness,metallic,thickness,_NormalDistortion,_SSSRange,mainLightShadow);

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
				    additionalColor += CalculateDiffuseBRDFResult(nDir,additionalLightDir,vDir,albedo.rgb,additionalLightRadiance,smoothness,metallic,thickness,_NormalDistortion,_SSSRange,additionalLight.shadowAttenuation);
				}
            	
            	half3 MainFinalRGB = mainColor+additionalColor;

            	half3 FinalRGB = MainFinalRGB;
            	
                return half4(FinalRGB,1.0);
            }
    		
    		half4 frag_mask (vertexOutput i) : SV_TARGET
            {
                return half4(1,1,1,1.0);
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
	        Tags{"LightMode"="DiffuseBRDF"}
            
            cull off
             
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag_diffuse
            
            ENDHLSL
        }

	    pass
        {
	        Tags{"LightMode"="SSSMask"}
            
            cull off
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag_mask
            
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