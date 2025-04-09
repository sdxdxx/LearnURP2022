Shader "URP/PostProcessing/Custom_SSAO"
{
    Properties
    {
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
    }
    
    SubShader
    {
        Tags{
            "RenderPipeline" = "UniversalPipeline"  
            "RenderType"="Opaque"
        }
        
        Cull Off 
        ZWrite Off
        ZTest Always
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
        #include  "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

        //----------贴图声明开始-----------
            TEXTURE2D(_CameraOpaqueTexture);//获取到摄像机渲染画面的Texture
            SAMPLER(sampler_CameraOpaqueTexture);
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
			TEXTURE2D(_MyDepthTex);
            SAMPLER(sampler_MyDepthTex);
            TEXTURE2D(_CameraNormalsTexture);
            SAMPLER(sampler_CameraNormalsTexture);
            
            //----------贴图声明结束-----------
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            //float4 _CameraOpaqueTexture_ST;
            float _Intensity;
			float _CullValue;
            float _DepthBias;
            int _SampleCount;
            float _SampleRadius;
            float _InsideRadius;

            float4 _BlurRadius;
            float _BilaterFilterFactor;
            //----------变量声明结束-----------
            CBUFFER_END

			float Random(float2 p)
			{
				return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
			}

            float3 ReconstructViewPositionFromDepth(float2 screenPos, float depth01)
            {
                float2 ndcPos = screenPos*2-1;//map[0,1] -> [-1,1]
            	float3 viewPos;
                if (unity_OrthoParams.w)
                {
                	viewPos = float3(unity_OrthoParams.xy * ndcPos.xy, 0);
                	viewPos.z = -lerp(_ProjectionParams.y, _ProjectionParams.z, depth01);
                }
                else
                {
                	float3 clipPos = float3(ndcPos.x,ndcPos.y,1)*_ProjectionParams.z;// z = far plane = mvp result w
	                viewPos = mul(unity_CameraInvProjection,clipPos.xyzz).xyz * depth01;
                }
            	
                return viewPos;
            }

			float GetDepth01(float rawDepth)
            {
            	float depth01;
	            if (unity_OrthoParams.w)
	            {
		             depth01 = 1-rawDepth;
	            }
	            else
	            {
		             depth01 = Linear01Depth(rawDepth,_ZBufferParams);
	            }

            	return depth01;
            }

			float2 GetScreenPos(float3 posVS)
            {
                float2 screenPos;
                if (unity_OrthoParams.w>0.5)
                {
                    float2 ndcPos = posVS.xy/unity_OrthoParams.xy;
                    screenPos = ndcPos*0.5+0.5;
                }
                else
                {
                    float3 clipPos = mul((float3x3)unity_CameraProjection, posVS);
                    screenPos = (clipPos.xy / clipPos.z) * 0.5 + 0.5;
                }
                return screenPos;
            }
        ENDHLSL

        pass
        {
            Name "SSAO_Pass"
            
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment frag_AO

            // 获取半球上随机一点
			float3 PickSampleVector(float2 uv, int sampleIndex, half rcpSampleCount, half3 normal)
            {
			    // 一坨随机数
			    half gradientNoise = InterleavedGradientNoise(uv * _ScreenParams.xy, sampleIndex);
			    half u = frac(Random(half2(0.0, sampleIndex)) + sin(gradientNoise*2*PI)) * 2.0 - 1.0;
			    half theta = Random(half2(1.0, sampleIndex) + sin(gradientNoise*2*PI)) * TWO_PI;
			    half u2 = sqrt(1.0 - u * u);

			    // 全球上随机一点
			    half3 v = half3(u2 * cos(theta), u2 * sin(theta), u);
			    v *= sqrt(sampleIndex * rcpSampleCount); // 随着采样次数增大越向外采样

			    // 半球上随机一点 逆半球法线翻转
			    // https://thebookofshaders.com/glossary/?search=faceforward
			    v = faceforward(v, -normal, v); // 确保v跟normal一个方向
            	
			    return v;
			}

            
            half4 frag_AO (Varyings i) : SV_TARGET
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

            	//Preparation
                float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_CameraDepthTexture,i.texcoord).r;
                float3 nDirWS = SAMPLE_TEXTURE2D_X(_CameraNormalsTexture,sampler_CameraNormalsTexture,i.texcoord).xyz;
                float3 nDirVS = TransformWorldToViewNormal(nDirWS);//View Space Normal Direction
                float linear01Depth = GetDepth01(rawDepth);
                float3 posVS_frag = ReconstructViewPositionFromDepth(i.texcoord,linear01Depth);//View Space Frag Pos
            	float2 lastSampleScreenPos = i.texcoord;
            	
                //Core
                float ao = 0;
                float sampleCount = _SampleCount;
            	float rcpSampleCount = rcp(sampleCount);

            	UNITY_LOOP
                for(int index = 1; index<=sampleCount; index++)
                {
                    float3 randomSampleVec = PickSampleVector(lastSampleScreenPos,index,rcpSampleCount,nDirVS);
                	
                     //Calculate Normal-Oriented Hemisphere Vector
                    float3 randomSamplePosVS = posVS_frag + randomSampleVec * _SampleRadius;
                    float2 randomSampleScreenPos = GetScreenPos(randomSamplePosVS);
                	lastSampleScreenPos = randomSampleScreenPos;
                	

                    if (randomSampleScreenPos.x >1 || randomSampleVec.y >1)
                    {
	                    ao += 0;
                    	continue;
                    }
                	
                    //Calculate Sample Point Depth
                    float OcculusionPoint01Depth;
                    float OcculusionPointRawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_CameraDepthTexture,randomSampleScreenPos).r;
                    OcculusionPoint01Depth = GetDepth01(OcculusionPointRawDepth);

                	//Calculate Randomly Sampled View Space Frag Position
                	float3 OcculusionPointPosVS = ReconstructViewPositionFromDepth(randomSampleScreenPos,OcculusionPoint01Depth);
                	float3 OcculusionVec = normalize(OcculusionPointPosVS-posVS_frag);

                	//Calculate AO
                    float isInsideRadius = abs(OcculusionPoint01Depth - linear01Depth) <_InsideRadius ? 1.0 : 0.0;
                    float selfCheck = OcculusionPoint01Depth+_DepthBias < linear01Depth ? 1.0 : 0.0;//Calculate Depth Difference

                	//Distance Weight
                    float weight1 = lerp(1,0.8,index/sampleCount);
                	
                	//Angle Weight
                	float cosAngle =  dot(OcculusionVec,nDirVS);
                	float weight2 = saturate(cosAngle);

                	//Add AO
                	ao+= selfCheck * weight1*isInsideRadius*0.3f+weight2*isInsideRadius*selfCheck*0.7f;
                }
                
                ao = ao/sampleCount;
            	ao = smoothstep(_CullValue+0.001,1.0,ao);
		        ao = max(0.0, 1-ao*_Intensity);
                return float4(ao,ao,ao,1);
                
            }
            
            ENDHLSL
        }
        
        pass
        {
            Name "Blur_Pass"
             HLSLPROGRAM
             
            #pragma vertex Vert
            #pragma fragment frag_blur

             ///基于法线的双边滤波（Bilateral Filter）
			//https://blog.csdn.net/puppet_master/article/details/83066572
			float3 GetNormal(float2 uv)
			{
				float3 nDirWS = SAMPLE_TEXTURE2D_X(_CameraNormalsTexture,sampler_CameraNormalsTexture,uv).xyz;
                float3 nDirVS = TransformWorldToViewNormal(nDirWS);//视角空间下法线的坐标
            	return nDirVS;
			}

			half CompareNormal(float3 nor1,float3 nor2)
			{
				return smoothstep(_BilaterFilterFactor,1.0,dot(nor1,nor2));
			}

             float4 _BlitTexture_TexelSize;
             half4 frag_blur (Varyings i) : SV_TARGET
            {
            	UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
            	
                //_MainTex_TexelSize -> https://forum.unity.com/threads/_maintex_texelsize-whats-the-meaning.110278/
            	
				float2 delta = _BlitTexture_TexelSize.xy * _BlurRadius.xy;
				
				float2 uv = i.texcoord;
				float2 uv0a = uv - delta;
				float2 uv0b = uv + delta;	
				float2 uv1a = uv - 2.0 * delta;
				float2 uv1b = uv + 2.0 * delta;
				float2 uv2a = uv - 3.0 * delta;
				float2 uv2b = uv + 3.0 * delta;
				
				float3 normal = GetNormal(uv);
				float3 normal0a = GetNormal(uv0a);
				float3 normal0b = GetNormal(uv0b);
				float3 normal1a = GetNormal(uv1a);
				float3 normal1b = GetNormal(uv1b);
				float3 normal2a = GetNormal(uv2a);
				float3 normal2b = GetNormal(uv2b);
            	
				half4 col = SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,uv);
				half4 col0a = SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,uv0a);
				half4 col0b = SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,uv0b);
				half4 col1a = SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,uv1a);
				half4 col1b = SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,uv1b);
				half4 col2a = SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,uv2a);
				half4 col2b = SAMPLE_TEXTURE2D(_BlitTexture,sampler_LinearClamp,uv2b);
				
				half w = 0.37004405286;
				half w0a = CompareNormal(normal, normal0a) * 0.31718061674;
				half w0b = CompareNormal(normal, normal0b) * 0.31718061674;
				half w1a = CompareNormal(normal, normal1a) * 0.19823788546;
				half w1b = CompareNormal(normal, normal1b) * 0.19823788546;
				half w2a = CompareNormal(normal, normal2a) * 0.11453744493;
				half w2b = CompareNormal(normal, normal2b) * 0.11453744493;
				
				half3 result;
				result = w * col.rgb;
				result += w0a * col0a.rgb;
				result += w0b * col0b.rgb;
				result += w1a * col1a.rgb;
				result += w1b * col1b.rgb;
				result += w2a * col2a.rgb;
				result += w2b * col2b.rgb;
				
				result /= w + w0a + w0b + w1a + w1b + w2a + w2b;
            	
				return half4(result, 1.0);
            }
             ENDHLSL
        }
        
        pass
        {
            Name "Composite_Pass"
            
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment frag_Composite

            TEXTURE2D(_AOTex);
            SAMPLER(sampler_AOTex);
            
            half4 frag_Composite (Varyings i) : SV_TARGET
            {
            	UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                half3 albedo = SAMPLE_TEXTURE2D_X(_BlitTexture,sampler_LinearClamp, i.texcoord).rgb;
                half ao = SAMPLE_TEXTURE2D(_AOTex,sampler_AOTex,i.texcoord).x;
                return float4(albedo*ao,1.0);
            }
            ENDHLSL
        }

    }
}