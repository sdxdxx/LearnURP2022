Shader "URP/PixelizeObject"
{
    Properties
    {
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _MainTex("MainTex",2D) = "white"{}
    	_Smoothness("Smoothness",Range(0,1)) = 0
    	_Metallic("Metallic",Range(0,1)) = 0
    	_OutlineColor("Outline Color",Color) = (0.0,0.0,0.0,0.0)
        _OutlineWidth("Outline Width",Range(0,5)) = 1
    }
    
    SubShader
    {
         Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }
         
        HLSLINCLUDE
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

            // 主光源和阴影
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT

            // 多光源和阴影
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS

    		#define kDielectricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04)
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);//定义贴图
            SAMPLER(sampler_MainTex);//定义采样器
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float4 _MainTex_ST;
            float _Smoothness;
            float _Metallic;
            half4 _OutlineColor;
            float _OutlineWidth;
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

            half3 CalculatePBRResult(float3 nDir, float3 lDir, float3 vDir, half3 MainTex, half3 lightCol, float smoothness, float metallic, float shadow)
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
				half3 ambient_contrib = SampleSH(nDir);//反射探针接收

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
            	
            	float3 result_RBR = DirectLightResult*shadow + IndirectResult*lightCol;

            	return  result_RBR;
            }
            
            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            	float3 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 nDirOS : TEXCOORD1;
                float3 posOS : TEXCOORD2;
            	float4 screenPos : TEXCOORD3;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
            	float4 posCS = TransformObjectToHClip(v.vertex.xyz);
            	o.screenPos = ComputeScreenPos(posCS);
                o.pos = posCS;
                o.nDirOS = v.normal;
                o.uv = v.uv*_MainTex_ST.xy+_MainTex_ST.zw;
                o.posOS = v.vertex.xyz;
                return o;
            }

             half4 frag (vertexOutput i) : SV_TARGET
            {

            	float3 posWS = TransformObjectToWorld(i.posOS);
                float4 shadowCoord = TransformWorldToShadowCoord(posWS);
            	
            	
                Light mainLight = GetMainLight(shadowCoord);
                half3 mainLightColor = mainLight.color;
            	float3 mainLightDir = mainLight.direction;
            	float mainLightShadow = MainLightRealtimeShadow(shadowCoord);

            	float3 nDir = TransformObjectToWorldNormal(i.nDirOS);//空间转换在像素着色器完成效果会更好，不会出现顶点网格，但性能消耗增大
            	float3 vDir = normalize(_WorldSpaceCameraPos.xyz - posWS.xyz);
            	
            	half4 albedo = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv)*_BaseColor;

            	float metallic = _Metallic;
            	float smothness = _Smoothness-0.01;

            	float3 mainLightRadiance = mainLight.color * mainLight.distanceAttenuation;
            	half3 mainColor = CalculatePBRResult(nDir,mainLightDir,vDir,albedo.rgb,mainLightRadiance,smothness,metallic,mainLightShadow);

            	uint lightCount = GetAdditionalLightsCount();
            	half3 additionalColor = half3(0,0,0);
				for (uint lightIndex = 0; lightIndex < lightCount; lightIndex++)
				{
				    Light additionalLight = GetAdditionalLight(lightIndex, posWS, 1);
					half3 additionalLightColor = additionalLight.color;
					float3 additionalLightDir = additionalLight.direction;
					// 光照衰减和阴影系数
                    float3 additionalLightRadiance = additionalLight.color * additionalLight.distanceAttenuation;
				    additionalColor += CalculatePBRResult(nDir,additionalLightDir,vDir,albedo.rgb,additionalLightRadiance,smothness,metallic,additionalLight.shadowAttenuation);
				}

            	half3 FinalRGB = mainColor+additionalColor;
            	
            	half4 result = half4(FinalRGB,1.0);
            	
                return result;
            }
            
        ENDHLSL
         
		//解决深度引动模式Depth Priming Mode问题
        UsePass "Universal Render Pipeline/Unlit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/DepthNormals"
        
         pass
        {
        	Tags { "LightMode" = "UniversalForward" }
        	Cull Back
        	ZWrite On
        	
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            ENDHLSL
        }

		//Outline
        pass
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            Cull Front
            HLSLPROGRAM

            #pragma vertex vert_outline
            #pragma fragment frag_outline
            
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            
            vertexOutput vert_outline (vertexInput v)
            {
                vertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz+v.normal* _OutlineWidth * 0.1);
                //float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            half4 frag_outline (vertexOutput i) : SV_TARGET
            {
                return _OutlineColor;
            }
            
            ENDHLSL
        }

		pass
        {
	        Name "PixelizeMask"

        	Tags{"LightMode" = "PixelizeMask"}
	        
        	ZWrite On
        	ZTest LEqual
            HLSLPROGRAM
            
            #pragma vertex vert_PixelizeMask
            #pragma fragment frag_PixelizeMask

            #pragma shader_feature IS_ORTH_CAM

            //Remap
            float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
             {
               return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
             }
            

             vertexOutput vert_PixelizeMask (vertexInput v)
            {
                vertexOutput o;
            	v.vertex.xyz = v.vertex.xyz+v.normal* _OutlineWidth * 0.1;
            	float4 posCS = TransformObjectToHClip(v.vertex.xyz);
            	o.screenPos = ComputeScreenPos(posCS);
                o.pos = posCS;
                o.nDirOS = v.normal;
                o.uv = v.uv*_MainTex_ST.xy+_MainTex_ST.zw;
                o.posOS = v.vertex.xyz;
                return o;
            }

            half4 frag_PixelizeMask (vertexOutput i) : SV_TARGET
            {
            	float3 nDir = TransformObjectToWorldNormal(i.nDirOS).xyz;
            	float3 posWS = TransformObjectToWorld(i.posOS).xyz;
	            float isOrtho = UNITY_MATRIX_P[3][3];
            	float rawDepth;
            	
            	#ifdef IS_ORTH_CAM
            		//float linearEyeDepth = distance(_WorldSpaceCameraPos.xyz,posWS.xyz);
            		float linearEyeDepth = LinearEyeDepth(posWS,unity_MatrixV);
            		rawDepth = 1-(linearEyeDepth - _ProjectionParams.y) / (_ProjectionParams.z - _ProjectionParams.y);
            		return half4(1,rawDepth,0,0);
            	#else
            		float linearEyeDepth = TransformObjectToHClip(i.posOS).w;
            		rawDepth = (rcp(linearEyeDepth)-_ZBufferParams.w)/_ZBufferParams.z;
            	#endif

            	return half4(1,rawDepth,0,0);
            }
            
            ENDHLSL
        }


    }
}