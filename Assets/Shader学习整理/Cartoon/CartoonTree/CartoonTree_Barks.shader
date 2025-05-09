Shader "URP/CartoonTree/Barks"
{
    Properties
    {
    	[Header(Main Layer)]
    	_MainTex("Main Texture",2D) = "white"{}
    	
    	[Header(PBR)]
        _ColorTint("Color Tint",Color) = (1.0,1.0,1.0,1.0)
        _DarkColor("Dark Color",Color) = (0,0,0,1.0)
    	_Smoothness("Smoothness",Range(0,1)) = 0
    	_Metallic("Metallic",Range(0,1)) = 0
    	
    	[Header(Normal)]
    	_NormalMap("Normal Map",2D) = "bump"{}
    	_NormalInt("Normal Intensity",Range(0,5)) = 1
        
        [Header(Depth Rim)]
    	_RimCol("Rim Color",Color) = (1,1,1,1)
        _RimWidth("Rim Width",float) = 1
    	
	    [Header(Wind)]
    	_WindDistortionMap("Wind Distortion Map", 2D) = "white" {}
        _WindFrequency("Wind Frequency", Vector) = (0.05, 0.05, 0, 0)
    	_WindStrength("Wind Strength", Range(0,1)) = 1
    	
    	[Header(SubLayer)]
    	[Toggle(_EnableSubLayer)]_EnableSubLayer("Enable SublLayer",float) = 0.0
    	_SubTex("SubTexture",2D) = "white"{}
    	
    	[Header(SubLayer PBR)]
        _SubLayerColorTint("SubLayer Color Tint",Color) = (1.0,1.0,1.0,1.0)
        _SubLayerDarkColor("SubLayer Dark Color",Color) = (0,0,0,1.0)
    	_SubLayerSmoothness("SubLayer Smoothness",Range(0,1)) = 0
    	_SubLayerMetallic("SubLayer Metallic",Range(0,1)) = 0
    	
    	[Header(SubLayer Normal)]
    	_SubLayerNormalMap("SubLayer Normal Map",2D) = "bump"{}
    	_SubLayerNormalInt("SubLayer Normal Intensity",Range(0,5)) = 1
    	
    	[Header(SubLayer Depth Rim)]
    	_SubLayerRimCol("Rim Color",Color) = (1,1,1,1)
    	
    	[Header(Mask)]
    	[Toggle(_EnableSubLayerMask)]_EnableSubLayerMask("Enable SublLayer Mask",float) = 0.0
    	_SubLayerMask("SubLayer Mask",2D) = "white"{}
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

    		#pragma shader_feature _EnableSubLayer
    		#pragma shader_feature _EnableSubLayerMask
    	
    		#define kDielectricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04)
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);//定义贴图
            SAMPLER(sampler_MainTex);//定义采样器
    		TEXTURE2D(_WindDistortionMap);
	        SAMPLER(sampler_WindDistortionMap);
    		TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
    		TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

    		TEXTURE2D(_SubTex);//定义贴图
            SAMPLER(sampler_SubTex);//定义采样器
    		TEXTURE2D(_SubLayerNormalMap);
            SAMPLER(sampler_SubLayerNormalMap);
    		TEXTURE2D(_SubLayerMask);
    		SAMPLER(sampler_SubLayerMask);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _ColorTint;
            half4 _DarkColor;

    		float _NormalInt;
    		float4 _NormalMap_ST;
            
            float _Smoothness;
            float _Metallic;
    	
            half4 _RimCol;
            float _RimWidth;
    	
            float4 _MainTex_ST;
    	
    		float3 _windEffectedPos;

    		float4 _WindDistortionMap_ST;
	        float2 _WindFrequency;
	        float _WindStrength;

    		half4 _SubLayerColorTint;
            half4 _SubLayerDarkColor;

    		float _SubLayerNormalInt;
    		float4 _SubLayerNormalMap_ST;
            
            float _SubLayerSmoothness;
            float _SubLayerMetallic;

    		half4 _SubLayerRimCol;

    		float4 _SubTex_ST;
    		float4 _SubLayerMask_ST;
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

    		//AngleAxis3x3()接收一个角度（弧度制）并返回一个围绕提供轴旋转的矩阵
	       float3x3 AngleAxis3x3(float angle, float3 axis)
	       {
	          float c, s;
	          sincos(angle, s, c);

	          float t = 1 - c;
	          float x = axis.x;
	          float y = axis.y;
	          float z = axis.z;

	          return float3x3(
	             t * x * x + c, t * x * y - s * z, t * x * z + s * y,
	             t * x * y + s * z, t * y * y + c, t * y * z - s * x,
	             t * x * z - s * y, t * y * z + s * x, t * z * z + c
	             );
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
            	float4 shadowCoord : TEXCOORD4;
            	float3 tDirWS : TEXCOORD5;
            	float3 bDirWS : TEXCOORD6;
            	float4 color : TEXCOORD7;
            };

            vertexOutput vert (vertexInput v)
            {
            	

            	
            	
            	
                vertexOutput o;


            	float2 uv = _windEffectedPos.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;
	            float windStrength = _WindStrength*0.1f+0.001f;
	            float2 windSample = (SAMPLE_TEXTURE2D_LOD(_WindDistortionMap,sampler_WindDistortionMap, uv,0).xy * 2 - 1) * windStrength;
	            

            	float3 wind = normalize(float3(windSample.x,windSample.y,0));

            	
	            float3x3 windRotation = AngleAxis3x3(PI * windSample.x, wind);

            	
            	o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
            	
            	o.tDirWS = normalize(TransformObjectToWorld(v.tangent));
            	o.bDirWS = normalize(mul(o.nDirWS,o.tDirWS)*v.tangent.w);
            	
            	v.vertex.xyz = mul(windRotation,v.vertex);
            	
            	float3 posWS = TransformObjectToWorld(v.vertex.xyz);
            	float4 posCS = TransformObjectToHClip(v.vertex.xyz);
                o.pos = posCS;
            	o.posWS = TransformObjectToWorld(v.vertex);
            	o.shadowCoord = TransformWorldToShadowCoord(o.posWS);
            	o.screenPos = ComputeScreenPos(posCS);
            	o.color = v.color;
            	
                return o;
            }

    		half3 CalculatePBRResult(float3 nDir, float3 lDir, float3 vDir, half3 MainTex, float smoothness, float metallic, float shadow)
            {
				float3 hDir = normalize(vDir+lDir);

				float nDotl = max(saturate(dot(nDir,lDir)),0.000001);
				float nDotv = max(saturate(dot(nDir,vDir)),0.000001);
				float hDotv = max(saturate(dot(vDir,hDir)),0.000001);
				float hDotl = max(saturate(dot(lDir,hDir)),0.000001);
				float nDoth = max(saturate(dot(nDir,hDir)),0.000001);

				//光照颜色
				float3 lightCol = _MainLightColor.rgb;

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

				//因为之前少给漫反射除了一个PI，为保证漫反射和镜面反射比例所以多乘一个PI
				float3 specColor = SpecularResult * lightCol * nDotl * PI;
				 
				//直接光漫反射部分
				//漫反射系数
				float kd = (1-F)*(1-metallic);

				float3 diffColor = kd*Albedo*lightCol*nDotl;//此处为了达到和Unity相近的渲染效果也不去除这个PI

				 float3 DirectLightResult = diffColor + specColor;

				//间接光漫反射
				half3 ambient_contrib = SampleSH(nDir);

				float3 ambient = 0.03 * Albedo;

				float3 iblDiffuse = max(half3(0, 0, 0), ambient.rgb + ambient_contrib);
				float3 Flast = fresnelSchlickRoughness(max(nDotv, 0.0), F0, roughness);
				 float kdLast = (1 - Flast) * (1 - metallic);

				float3 iblDiffuseResult = iblDiffuse * kdLast * Albedo;

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
				float4 IndirectResult = float4(iblDiffuse * kdLast * Albedo + iblSpecular * surfaceReduction * FresnelLerp(F0, grazingTerm, nDotv), 1);
            	
            	float3 result_RBR = lerp(DirectLightResult*_DarkColor,DirectLightResult,shadow) + IndirectResult*_MainLightColor.rgb;

            	return  result_RBR;
            }

    		half3 CalculateDepthRim(float4 screenPos, float3 nDirVS, half3 RimColor, float RimOffset)
            {
            	float2 screenPos_Modified = screenPos.xy/screenPos.w;
				float2 screenPos_Offset = screenPos_Modified + nDirVS.xy*RimOffset*0.001f/max(1,screenPos);//偏移后的视口坐标
				float depthOffsetTex = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,screenPos_Offset);
				float depthTex = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,screenPos_Modified);
				float depthOffset = Linear01Depth(depthOffsetTex,_ZBufferParams);
				float depth = Linear01Depth(depthTex,_ZBufferParams);
				float screenDepthRim = saturate(depthOffset - depth);
            	half3 depthRim = screenDepthRim*RimColor;
            	return depthRim;
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
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,mainTexUV);
            	mainTex.rgb *=_ColorTint.rgb; 
            	
            	//TBN Matrix & SampleNormalMap
				 float3x3 TBN = float3x3(i.tDirWS,i.bDirWS,i.nDirWS);
            	float2 normalUV = i.uv*_NormalMap_ST.xy+_NormalMap_ST.zw;
            	float4 packedNormal = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,normalUV);
            	float3 var_NormalMap = UnpackScaleNormal(packedNormal,_NormalInt);

				//Vector
				float3 nDir = normalize(mul(var_NormalMap,TBN));
            	float3 nDirVS = normalize(mul((float3x3)UNITY_MATRIX_V, i.nDirWS));
            	float3 lDir = normalize(_MainLightPosition.xyz);
            	float3 vDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
            	
            	//depth rim
            	half3 depthRim = CalculateDepthRim(i.screenPos,nDirVS,_RimCol,_RimWidth);

            	//shadow
            	float shadow = MainLightRealtimeShadow(i.shadowCoord);

            	//PBR
            	half3 result_RBR = CalculatePBRResult(nDir,lDir,vDir,mainTex,_Smoothness,_Metallic,shadow);
            	
            	half3 MainFinalRGB = result_RBR+depthRim;

            	half3 FinalRGB = MainFinalRGB;

            	//SubLayer
            	#ifdef _EnableSubLayer
            	float2 subLayerNormalUV = i.uv*_SubLayerNormalMap_ST.xy+_SubLayerNormalMap_ST.zw;
            	float4 subLayerPackedNormal = SAMPLE_TEXTURE2D(_SubLayerNormalMap,sampler_SubLayerNormalMap,subLayerNormalUV);
            	float3 var_subLayerNormalMap = UnpackScaleNormal(subLayerPackedNormal,_SubLayerNormalInt);
            	float3 nDirTS_subLayer  =NormalBlendReoriented(var_NormalMap,var_subLayerNormalMap);
            	float3 nDir_subLayer = normalize(mul(nDirTS_subLayer,TBN));
            	float2 subTexUV = i.uv *_SubTex_ST.xy+_SubTex_ST.zw;
                half4 subTex = SAMPLE_TEXTURE2D(_SubTex,sampler_SubTex,subTexUV);
            	subTex.rgb *=_SubLayerColorTint.rgb;
            	half3 subResult_RBR = CalculatePBRResult(nDir_subLayer,lDir,vDir,subTex,_SubLayerSmoothness,_SubLayerMetallic,shadow);
            	half3 subDepthRim = CalculateDepthRim(i.screenPos,nDirVS,_SubLayerRimCol,_RimWidth);
            	half3 SubFinalRGB = subResult_RBR+subDepthRim;
            	float subLayerMask =i.color.r; 
            	#ifdef _EnableSubLayerMask
            	float2 subLayerMaskUV = i.uv*_SubLayerMask_ST.xy+_SubLayerMask_ST.zw;
            	subLayerMask = SAMPLE_TEXTURE2D(_SubLayerMask,sampler_SubLayerMask,subLayerMaskUV);
            	#endif
            	
            	FinalRGB = lerp(MainFinalRGB,SubFinalRGB,subLayerMask);
				#endif
            	
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
			return 1;
		 }

		ENDHLSL
		}
    }
}