Shader "URP/Cartoon/PixelizeObject"
{
    Properties
    {
        [Header(Tint)]
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        
        _MainTex("MainTex",2D) = "white"{}
        
        [Header(MatCap)]
        _MatCap("Mat Cap",2D) = "white"{}
        _MatCapLerp("MatCapLerp",Range(0,1)) = 1
        
         [Header(Diffuse)]
        _RangeDark("Range Dark",Range(0,1)) = 0.3
        _SmoothDark("Smooth Dark",Range(0,0.2)) = 0
        _RangeLight("Range Light",Range(0,1)) = 0.7
        _SmoothLight("Smooth Light",Range(0,0.2)) = 0
        _LightColor("Light Color",Color) = (1,1,1,1)
        _GreyColor("Grey Color",Color) = (0.5,0.5,0.5,1)
        _DarkColor("Dark Color",Color) = (0,0,0,1)
        
        [Header(Specular)]
        _SpecularIntensity("Specular Intensity",Range(0,1)) = 1
        _SpecularPow("Specular Power",Range(0.1,200)) = 50
        _SpecularColor("Specular Color",Color) = (1,1,1,1)
        _RangeSpecular("Range Specular",Range(0,1)) = 0.9
        _SmoothSpecular("Smooth Specular",Range(0,0.2)) = 0
        
        [Header(Outline)]
        _OutlineColor("Outline Color",Color) = (0.0,0.0,0.0,0.0)
        _OutlineWidth("Outline Width",Range(0,5)) = 1
    	
    	[Header(DownSample)]
    	[IntRange]_DownSampleValue("Down Sample Value",Range(0,5)) = 0
        _DownSampleBias("Down Sample Bias",Range(0,5)) = 0
    	[IntRange]_ID("Mask ID", Range(0,254)) = 100
    	
    	_InlineWidth("Inline Width Control",Range(0,1)) = 0
    }
    
    SubShader
    {
         Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        	"Queue" = "AlphaTest"
        }
         
         HLSLINCLUDE
         #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
         CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            half4 _LightColor;
            half4 _GreyColor;
            half4 _DarkColor;
            float _RangeDark;
            float _RangeLight;
            float _SmoothDark;
            float _SmoothLight;
            float _MatCapLerp;
            float4 _MainTex_ST;

            float _SpecularIntensity;
            float _SpecularPow;
            half4 _SpecularColor;
            float _RangeSpecular;
            float _SmoothSpecular;
            float _InlineWidth;
			int _DownSampleValue;
			float _DownSampleBias;
            //----------变量声明结束-----------
            CBUFFER_END

         TEXTURE2D(_CameraDepthTexture);
		 SAMPLER(sampler_CameraDepthTexture);
         ENDHLSL
    	
    	//解决深度引动模式Depth Priming Mode问题
        UsePass "Universal Render Pipeline/Unlit/DepthOnly"
        UsePass "Universal Render Pipeline/Unlit/DepthNormalsOnly"
        
        //Cartoon Rendering
        Pass
        {
            Tags { "LightMode" = "UniversalForward" }
            
            
            Stencil
            {
                Ref [_ID]
                Comp Always
                Pass Replace
            }
            
            Cull Back
            
            ZWrite On
            
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            // 主光源和阴影
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT

            // 多光源和阴影
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);//定义贴图
            SAMPLER(sampler_MainTex);//定义采样器
            TEXTURE2D(_MatCap);
            SAMPLER(sampler_MatCap);
            
            //----------贴图声明结束-----------
            
            

            //Remap
            float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
             {
               return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
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
                float3 nDirWS : TEXCOORD1;
                float3 posWS : TEXCOORD2;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv*_MainTex_ST.xy+_MainTex_ST.zw;
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                o.posWS = positionWS;
                return o;
            }

            float CalculateDiffuseLightResult(float3 nDir, float3 lDir, float lightRadience, float shadow)
            {
                float nDotl = dot(nDir,lDir);
                float lambert = max(0,nDotl);
                float halfLambert = nDotl*0.5+0.5;
                half3 result = lambert*shadow*lightRadience;
                return result;
            }
            
            half4 frag (vertexOutput i) : SV_TARGET
            {
                float4 shadowCoord = TransformWorldToShadowCoord(i.posWS);
                Light mainLight = GetMainLight(shadowCoord);
                float3 nDir= i.nDirWS;
                float3 lDir = mainLight.direction;
                float3 vDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
                float3 hDir = normalize(lDir+vDir);

                float3 nDirVS = TransformWorldToViewDir(i.nDirWS);
                half3 matcap = SAMPLE_TEXTURE2D(_MatCap,sampler_MatCap,abs(nDirVS.xy*0.5+0.5)).rgb;

                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv*_MainTex_ST.xy+_MainTex_ST.zw);
                half4 albedo = _BaseColor*mainTex;
                
                float mainLightRadiance = mainLight.distanceAttenuation;
                float mainDiffuse = CalculateDiffuseLightResult(nDir,lDir,mainLightRadiance,mainLight.shadowAttenuation);

                uint lightCount = GetAdditionalLightsCount();
            	float additionalDiffuse = half3(0,0,0);
            	float additionalSpecular = half3(0,0,0);
				for (uint lightIndex = 0; lightIndex < lightCount; lightIndex++)
				{
				    Light additionalLight = GetAdditionalLight(lightIndex, i.posWS, 1);
					half3 additionalLightColor = additionalLight.color;
					float3 additionalLightDir = additionalLight.direction;
					// 光照衰减和阴影系数
                    float additionalLightRadiance =  additionalLight.distanceAttenuation;
					float perDiffuse = CalculateDiffuseLightResult(nDir,additionalLightDir,additionalLightRadiance,additionalLight.shadowAttenuation);
				    additionalDiffuse += perDiffuse;
				}

                float diffuse = mainDiffuse+additionalDiffuse;
                float diffuseDarkMask = 1-smoothstep(_RangeDark-_SmoothDark,_RangeDark,diffuse);//暗部
                float diffuseLightMask = smoothstep(_RangeLight-_SmoothLight,_RangeLight,diffuse);//亮部
                float diffuseGreyMask = 1-diffuseDarkMask-diffuseLightMask;//中部
                
                half3 Diffuse = albedo*(_DarkColor*diffuseDarkMask+diffuseGreyMask*_GreyColor+_LightColor*diffuseLightMask);
            	half3 Specular = _SpecularIntensity*pow(max(0,dot(nDir,hDir)),_SpecularPow);
                Specular = smoothstep(_RangeSpecular-_SmoothSpecular,_RangeSpecular,Specular)*_SpecularColor;
                
                half3 FinalRGB = lerp(1,matcap,_MatCapLerp)*Diffuse;//Matcap+Diffuse
                FinalRGB = saturate(FinalRGB+Specular);//添加高光
                return half4(FinalRGB,1.0);
            }
            
            ENDHLSL
        }

        //Outline
        Pass
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            
            
           Stencil
            {
                Ref [_ID]
                Comp NotEqual
            }
            
            ZWrite On
            Cull Front
            
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            //----------贴图声明开始-----------
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _OutlineColor;
            float _OutlineWidth;
            //----------变量声明结束-----------
            CBUFFER_END

            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float3 color : COLOR;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float3 nDirWS : TEXCOORD1;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz+v.color* _OutlineWidth * 0.1);
                o.nDirWS = TransformObjectToWorldNormal(v.color);
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                return _OutlineColor;
            }
            
            ENDHLSL
        }
        
       //PixelizeMask
        Pass
        {
	        Name "PixelizeMask"

        	Tags{"LightMode" = "PixelizeMask"}
	        
            HLSLPROGRAM
            
            #pragma vertex vert_PixelizeMask
            #pragma fragment frag_PixelizeMask

            #pragma shader_feature IS_ORTH_CAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

            //Remap
            float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
             {
               return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
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

            TEXTURE2D(_PixelizeObjectMask);
            SAMPLER(sampler_PixelizeMask);
            half4 _OutlineColor;
            float _OutlineWidth;
            int _ID;
            
             vertexOutput vert_PixelizeMask (vertexInput v)
            {
                vertexOutput o;
            	v.vertex.xyz = v.vertex.xyz+v.color* _OutlineWidth * 0.1;
            	float4 posCS = TransformObjectToHClip(v.vertex.xyz);
            	o.screenPos = ComputeScreenPos(posCS);
                o.pos = posCS;
                o.nDirOS = v.color;
                o.uv = v.uv;
                o.posOS = v.vertex.xyz;
                return o;
            }

            float4 frag_PixelizeMask (vertexOutput i) : SV_TARGET
            {
            	float2 screenPos = i.screenPos.xy/i.screenPos.w;
            	float3 posWS = TransformObjectToWorld(i.posOS).xyz;
            	
            	float rawDepth;
            	
            	#ifdef IS_ORTH_CAM
            		//float linearEyeDepth = distance(_WorldSpaceCameraPos.xyz,posWS.xyz);
            		float linearEyeDepth = LinearEyeDepth(posWS,unity_MatrixV);
            		rawDepth = 1-(linearEyeDepth - _ProjectionParams.y) / (_ProjectionParams.z - _ProjectionParams.y);
            	#else
            		float linearEyeDepth = TransformObjectToHClip(i.posOS).w;
            		rawDepth = (rcp(linearEyeDepth)-_ZBufferParams.w)/_ZBufferParams.z;
            	#endif
            	
            	float id = _ID;
            	id = id/255.0;
            	return float4(rawDepth,0,0,id);
            }
            
            ENDHLSL
        }

		//PixelizePass
		Pass
        {
	        Name "PixelizePass"

	        ZWrite On
        	Tags{"LightMode" = "PixelizePass"}
	        
            HLSLPROGRAM
            
            #pragma vertex vert_Pixelize
            #pragma fragment frag_Pixelize

            #pragma shader_feature IS_ORTH_CAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

            //Remap
            float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
             {
               return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
             }

            float CalculateClearObjectMaskReverse(float RawDepth, float MaskRawDepth)
            {
                float rawDepth = RawDepth;
                float maskRawDepth = MaskRawDepth;
                float linear01Depth = 0;
                float mask01Depth = 0;
                float bias = 0;

                #ifdef IS_ORTH_CAM
                    linear01Depth = 1-rawDepth;//lerp(0, _ProjectionParams.z, rawDepth);
                    mask01Depth = 1-maskRawDepth;
                    bias = 0.009;
                #else
                    linear01Depth = Linear01Depth(rawDepth,_ZBufferParams);
                    mask01Depth = Linear01Depth(maskRawDepth,_ZBufferParams);
                    bias = 0.04;
                #endif

                float clearObjectMask_Reverse = step(mask01Depth,linear01Depth+bias);

                return clearObjectMask_Reverse;
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

            TEXTURE2D(_PixelizeMask);
            TEXTURE2D(_PixelizeObjectMask);
            SAMPLER(sampler_PixelizeMask);
            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);
            half4 _OutlineColor;
            float _OutlineWidth;
            int _ID;

            half3 GetGray (half3 inColor)
            {
	            return dot (inColor , half3 (0.299,0.587,0.114));
            }
            
             vertexOutput vert_Pixelize (vertexInput v)
            {
                vertexOutput o;
            	v.vertex.xyz = v.vertex.xyz+v.color* _OutlineWidth * 0.1+v.color*_DownSampleBias*0.1;
            	float4 posCS = TransformObjectToHClip(v.vertex.xyz);
            	o.screenPos = ComputeScreenPos(posCS);
                o.pos = posCS;
                o.nDirOS = v.color;
                o.uv = v.uv;
                o.posOS = v.vertex.xyz;
                return o;
            }

            half4 frag_Pixelize (vertexOutput input) : SV_TARGET
            {
            	float2 screenPos = input.screenPos.xy/input.screenPos.w;
            	
            	float downSampleValue = pow(2,_DownSampleValue);
            	float2 size = floor(_ScreenParams.xy/downSampleValue);
                //float3 originPoint = float3(0,0,0);
            	float3 originPoint = TransformObjectToWorld(float3(0,0,0));
                float4 worldOriginToScreenPos1= ComputeScreenPos(TransformWorldToHClip(originPoint));
                float2 worldOriginToScreenPos2= worldOriginToScreenPos1.xy/worldOriginToScreenPos1.w;
                float2 realSampleUV = (floor((screenPos-worldOriginToScreenPos2)*size)+0.5)/size+worldOriginToScreenPos2;

            	float4 pixelizeObjectParam = SAMPLE_TEXTURE2D(_PixelizeObjectMask,sampler_PointClamp,screenPos);
            	float4 realPixelizeObjectParam = SAMPLE_TEXTURE2D(_PixelizeObjectMask,sampler_PointClamp,realSampleUV);
            	float rawMask = step(pixelizeObjectParam.a,1-0.0000001);
            	float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp, screenPos).r;
            	float realRawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp, realSampleUV).r;
            	float maskRawDepth = pixelizeObjectParam.r;
                float realMaskRawDepth = realPixelizeObjectParam.r;
            	float clearObjectMask_Reverse = CalculateClearObjectMaskReverse(rawDepth,realMaskRawDepth);
            	float realClearObjectMask_Reverse = CalculateClearObjectMaskReverse(realRawDepth,maskRawDepth);
            	
            	if ( realClearObjectMask_Reverse<0.5)
            	{
            		float2 sampleUVPerBias = downSampleValue/_ScreenParams;

            		float2 bias[4] = {float2(0,1),float2(1,0),float2(0,-1),float2(-1,0)};
            		
            		UNITY_LOOP
            		for (int i = 0; i<4; i++)
            		{
            			float2 realSampleUVBias = realSampleUV + bias[i]*sampleUVPerBias;
            			float4 realPixelizeObjectParam_Bias = SAMPLE_TEXTURE2D(_PixelizeObjectMask,sampler_PointClamp,realSampleUVBias);
            			float realRawDepth_Bias = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp, realSampleUVBias).r;
            			float realMaskRawDepth_Bias = realPixelizeObjectParam_Bias.r;
            			float realClearObjectMask_Reverse_Bias = CalculateClearObjectMaskReverse(realRawDepth_Bias,realMaskRawDepth_Bias);
            			
			            if (realClearObjectMask_Reverse_Bias)
			            {
			            	realSampleUV = realSampleUVBias;
			            	break;
			            }
            		}
            	}

            	half3 samplePixelizeColorRGB = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_PointClamp, realSampleUV);
            	
            	half3 grabTex = SAMPLE_TEXTURE2D(_CameraOpaqueTexture,sampler_CameraOpaqueTexture,screenPos);//像素化之前所有物体（包括背景）的图
            	
            	//TODO: 利用这个遮罩在绘制像素物体之前抓取一个背景图，将遮罩白色的部分替换成背景图
            	float clearObjectBackGroundMask =  rawMask-clearObjectMask_Reverse*rawMask;

            	
            	
            	half3 finalRGB = lerp(grabTex,samplePixelizeColorRGB,clearObjectMask_Reverse);
            	
            	half4 result = half4(finalRGB,1.0); 
				return result;
            }
            
            ENDHLSL
        }
    }
}