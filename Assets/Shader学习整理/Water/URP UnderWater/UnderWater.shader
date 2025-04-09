Shader "URP/PostProcessing/UnderWater"
{
    Properties
    {
    }
    
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "RenderPipeline" = "UniversalPipeline"  
        }
        
        Cull Off 
        ZWrite Off
        ZTest Always
        
    	//WaterMask
        pass
        {
            Tags{"LightMode"="UniversalForward"}
            
            Name "WaterMask"
             
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            //----------变量声明结束-----------
            CBUFFER_END

            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            	float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 nDirWS : TEXCOORD1;
            };
            
            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                return half4(1,1,1,1);
            }
            
            ENDHLSL
        }
        
    	//UnderWater
        pass
        {
            Name "UnderWater"
            
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
           #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            #include  "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_CameraOpaqueTexture);//获取到摄像机渲染画面的Texture
            SAMPLER(sampler_CameraOpaqueTexture);

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            
            TEXTURE2D(_CameraNormalsTexture);
            SAMPLER(sampler_CameraNormalsTexture);

            TEXTURE2D(_MyDepthTex);
            SAMPLER(sampler_MyDepthTex);
            
            TEXTURE2D(_WaterMask);
            SAMPLER(sampler_WaterMask);

            TEXTURE2D(_DistorationNoise);
            SAMPLER(sampler_DistorationNoise);
            
            TEXTURE2D(_CausticsTexture);
            SAMPLER(sampler_CausticsTexture);
            
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _UnderWaterDeepColor;
            half4 _UnderWaterShallowColor;
            float2 _DistorationNoise_Tilling;
            float _DistorationIntensity;
            float _DistorationSpeed;
            
            float3 _ViewPortPos[4];
            float4x4 _DepthCameraV2W;
            float _WaterPlaneHeight;

            float4x4 _MainCameraTransformMatrix;

            float _UnderWaterLineWidth;
            float _WaterLineSmooth;
            float _WaterLineOffset;
            half4 _WaterLineColor;

            float4 _WaveA;
            float4 _WaveB;
            float4 _WaveC;
            float _WaveInt;
            
            float _CausticsTextureScale;
            float _CausiticsSpeed;
            float _CausiticsIntensity;
            //----------变量声明结束-----------
            CBUFFER_END

            float3 ReconstructWorldPositionFromDepth(float2 screenPos, float rawDepth)
            {
                float2 ndcPos = screenPos*2-1;//map[0,1] -> [-1,1]
            	float3 worldPos;
                if (unity_OrthoParams.w)
                {
					float depth01 = 1-rawDepth;
                	float3 viewPos = float3(unity_OrthoParams.xy * ndcPos.xy, 0);
                	viewPos.z = -lerp(_ProjectionParams.y, _ProjectionParams.z, depth01);
                	worldPos = mul(UNITY_MATRIX_I_V, float4(viewPos, 1)).xyz;
                }
                else
                {
	                float depth01 = Linear01Depth(rawDepth,_ZBufferParams);
                	float3 clipPos = float3(ndcPos.x,ndcPos.y,1)*_ProjectionParams.z;// z = far plane = mvp result w
	                float3 viewPos = mul(unity_CameraInvProjection,clipPos.xyzz).xyz * depth01;
	                worldPos = mul(UNITY_MATRIX_I_V,float4(viewPos,1)).xyz;
                }
            	
                return worldPos;
            }
            
             float3 GerstnerWave (float4 wave, float3 p)
            {
			    float steepness = wave.z;
			    float wavelength = wave.w;
			    float k = 2 * PI / wavelength;
				float c = sqrt(9.8 / k);
				float2 d = normalize(wave.xy);
				float f = k * (dot(d, p.xz) - c * _Time.y);
				float a = steepness / k;
				
				p.x += d.x * (a * cos(f));
				p.y = a * sin(f);
				p.z += d.y * (a * cos(f));
            	
				return float3(
					d.x * (a * cos(f)),
					a * sin(f),
					d.y * (a * cos(f))
				);
		}
            
            half4 frag (Varyings i) : SV_TARGET
            {
                half4 albedo =  SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);
                float waterMask =  SAMPLE_TEXTURE2D(_WaterMask, sampler_LinearClamp, i.texcoord).r;

            	//UnderWaterMask
            	float3 viewPortFragWS = float3(0,0,0);
            	float3 xDir = _ViewPortPos[1]- _ViewPortPos[0];
            	float3 yDir = _ViewPortPos[2] - _ViewPortPos[0];
            	viewPortFragWS = _ViewPortPos[0]+i.texcoord.x*xDir+i.texcoord.y*yDir;

            	float3 waterPoint = float3(viewPortFragWS.x, _WaterPlaneHeight, viewPortFragWS.z);
            	waterPoint +=  GerstnerWave(_WaveA, waterPoint)*_WaveInt;
			    waterPoint += GerstnerWave(_WaveB, waterPoint)*_WaveInt;
			    waterPoint += GerstnerWave(_WaveC, waterPoint)*_WaveInt;

            	waterPoint.y += _WaterLineOffset*0.1f;
            	
            	float underWaterMask0 = 1-step(waterPoint.y,viewPortFragWS.y);
            	
            	//WaterLine
            	float waterLine_y1 = waterPoint.y-0.001*_UnderWaterLineWidth/2;
                float underWaterMask1 = smoothstep(waterLine_y1,waterLine_y1-_WaterLineSmooth*0.02,viewPortFragWS.y);
                
                float waterLine_y2 = waterPoint.y+0.001*_UnderWaterLineWidth/2;
                float underWaterMask2 = smoothstep(waterLine_y2,waterLine_y2+_WaterLineSmooth*0.02,viewPortFragWS.y);

            	float waterLine = 1-abs(underWaterMask1-underWaterMask2);

            	
            	//UnderWaterColor
            	float m_rawDepth =  SAMPLE_TEXTURE2D(_MyDepthTex, sampler_PointClamp, i.texcoord);
                float m_linearDepth = LinearEyeDepth(m_rawDepth,_ZBufferParams);
            	float m_depth01 = Linear01Depth(m_rawDepth,_ZBufferParams);
                if (unity_OrthoParams.w)
                {
	                m_depth01 = 1-m_rawDepth;
                	m_linearDepth = lerp(_ProjectionParams.y,_ProjectionParams.z,m_depth01);
                }
            	
            	float2 distorationNoise = SAMPLE_TEXTURE2D(_DistorationNoise,sampler_DistorationNoise,
            		i.texcoord*_DistorationNoise_Tilling+_Time.y*0.1*_DistorationSpeed);
            	float2 distorationUV = i.texcoord+distorationNoise/max(m_linearDepth,0.9)*_DistorationIntensity;
            	
            	float m_rawDepth_distoration =  SAMPLE_TEXTURE2D(_MyDepthTex, sampler_PointClamp, distorationUV);
                float m_depth01_distoration = Linear01Depth(m_rawDepth_distoration,_ZBufferParams);
            	if (unity_OrthoParams.w)
                {
	                m_depth01_distoration = 1-m_rawDepth_distoration;
                }
            	
            	float waterDepth = _WaterPlaneHeight - viewPortFragWS.y;
            	half3 waterCol = lerp(_UnderWaterDeepColor,_UnderWaterShallowColor,exp(-waterDepth));

            	float depthFog = pow(saturate(m_depth01_distoration*60),0.25);
            	half4 albedo_Distoration =  SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, distorationUV);
            	float3 underWaterCol = lerp(albedo_Distoration,waterCol,depthFog)*waterCol;
            	
            	//Caustics
            	float rawDepth_distoration =  SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_PointClamp, i.texcoord);
            	float3 posWS_Frag_distoration = ReconstructWorldPositionFromDepth(i.texcoord,rawDepth_distoration);
            	float2 causiticsUV = posWS_Frag_distoration.xz/_CausticsTextureScale;
                float2 causiticsUV1 = frac(causiticsUV+_Time.x*_CausiticsSpeed);
                float2 causiticsUV2 = frac(causiticsUV-_Time.x*_CausiticsSpeed);
                half3 CausiticsCol1 = SAMPLE_TEXTURE2D(_CausticsTexture,sampler_LinearRepeat,causiticsUV1+float2(0.1f,0.2f));
                half3 CausiticsCol2 = SAMPLE_TEXTURE2D(_CausticsTexture,sampler_LinearRepeat,causiticsUV2);
            	float3  CameraNormal = SAMPLE_TEXTURE2D(_CameraNormalsTexture,sampler_LinearRepeat,distorationUV);
            	float CausticsMask1 = saturate(CameraNormal.y*CameraNormal.y);
            	float CausticsMask2 = saturate(dot(CameraNormal,_MainLightPosition));
            	float CausticsMask = CausticsMask1*CausticsMask2;
                half3 CausiticsCol = min(CausiticsCol1,CausiticsCol2)*depthFog*_CausiticsIntensity*CausticsMask;
            	
            	half3 mainCol = lerp(albedo,saturate(underWaterCol+CausiticsCol),underWaterMask0);
            	half3 FinalRGB = lerp(mainCol,saturate(_WaterLineColor*0.9f+mainCol*0.1f),waterLine);

            	half4 result = half4(FinalRGB,1.0);
            	
                return result;
            }
            
            ENDHLSL
        }



    }
}