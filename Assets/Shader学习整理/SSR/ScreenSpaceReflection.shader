Shader "URP/PostProcessing/ScreenSpaceReflection"
{
    Properties
    {
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
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
        
        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            #include  "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            float3 ReconstructViewPositionFromDepth(float2 screenPos, float depth)
            {
                float2 ndcPos = screenPos*2-1;//map[0,1] -> [-1,1]
               float3 clipPos = float3(ndcPos.x,ndcPos.y,1)*_ProjectionParams.z;// z = far plane = mvp result w（由规律可知）
               float3 viewPos = mul(unity_CameraInvProjection,clipPos.xyzz).xyz * depth;
               return viewPos;
            }
        ENDHLSL
        
        //SSR Pass
        pass
        {
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag
            #pragma shader_feature SIMPLE_VS //基础视角空间SSR
            #pragma shader_feature BINARY_SEARCH_VS //视空间二分搜索SSR
            #pragma shader_feature BINARY_SEARCH_JITTER_VS //视空间二分搜索SSR+JitterDither
            #pragma shader_feature EFFICIENT_SS //逐像素屏幕空间SSR
            #pragma shader_feature EFFICIENT_JITTER_SS //逐像素屏幕空间SSR+JitterDither
            #pragma shader_feature HIZ_VS //HIZ算法SSR
            
            
            //----------贴图声明开始-----------
            TEXTURE2D(_CameraDepthTexture);
            //SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_CameraNormalsTexture);
            //SAMPLER(sampler_CameraNormalsTexture);
            TEXTURE2D(_CameraDepthTexture_MipLevel_2);
            TEXTURE2D(_CameraDepthTexture_MipLevel_3);
            TEXTURE2D(_CameraDepthTexture_MipLevel_4);
            TEXTURE2D(_CameraDepthTexture_MipLevel_5);
            TEXTURE2D(_CameraDepthTexture_MipLevel_6);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float4 _MainTex_ST;

            //Simple
            float _StepLength;
            float _Thickness;

            //BinarySearch
            float _MaxStepLength;
            float _MinDistance;

            //Efficient
            float _MaxReflectLength;
            int _DeltaPixel;

            //Jitter Dither
            float _DitherIntensity;
            
            //----------变量声明结束-----------
            CBUFFER_END

            //基础SSR
            half4 ScreenSpaceReflection_Simple(Varyings i)
            {
                float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp, i.texcoord).r;
                float linear01Depth = Linear01Depth(rawDepth,_ZBufferParams);
                float3 posVS = ReconstructViewPositionFromDepth(i.texcoord,linear01Depth);
                float3 nDirWS = SAMPLE_TEXTURE2D(_CameraNormalsTexture,sampler_PointClamp,i.texcoord).xyz;
                float3 nDirVS = TransformWorldToViewNormal(nDirWS);
                float3 sampleNormalizeVector = normalize(reflect(normalize(posVS),nDirVS));
                float3 samplePosVS = posVS;
                float stepLength = _StepLength;
                int maxStep = 128;
                float3 sampleClipPos;
                float2 sampleScreenPos;
                int step;
                
                half4 result = half4(1.0,1.0,1.0,1.0);
                
                UNITY_LOOP
                for (step = 1; step<=maxStep; step++)
                {
                    samplePosVS += sampleNormalizeVector*stepLength;
                    sampleClipPos = mul((float3x3)unity_CameraProjection, samplePosVS);
                    sampleScreenPos = (sampleClipPos.xy / sampleClipPos.z) * 0.5 + 0.5;
                    
                    if (sampleScreenPos.x>1 || sampleScreenPos.y >1)
                    {
                        //超出屏幕直接剔除
                        break;
                    }
                    
                    float sampleRawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp,sampleScreenPos).r;
                    float sampleLinearEyeDepth = LinearEyeDepth(sampleRawDepth,_ZBufferParams);
                    if ((sampleLinearEyeDepth<-samplePosVS.z)&&(-samplePosVS.z<(sampleLinearEyeDepth+_Thickness)))
                    {
                        float2 reflectScreenPos = sampleScreenPos;
                        half3 albedo_reflect =  SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, reflectScreenPos);
                        result.rgb = albedo_reflect*_BaseColor;
                        return result;
                    }
                }

                result = half4(0.0,0.0,0.0,1.0);
                return result;
            }

            //二分搜索SSR
            half4 ScreenSpaceReflection_BinarySearch(Varyings i)
            {
                float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp, i.texcoord).r;
                float linear01Depth = Linear01Depth(rawDepth,_ZBufferParams);
                float3 posVS = ReconstructViewPositionFromDepth(i.texcoord,linear01Depth);
                float3 nDirWS = SAMPLE_TEXTURE2D(_CameraNormalsTexture,sampler_PointClamp,i.texcoord).xyz;
                float3 nDirVS = TransformWorldToViewNormal(nDirWS);
                float3 sampleNormalizeVector = normalize(reflect(normalize(posVS),nDirVS));
                float3 lastSamplePosVS = posVS;
                float3 samplePosVS = posVS;
                float stepLength = _MaxStepLength;
                int maxStep = 128;
                float3 sampleClipPos;
                float2 sampleScreenPos;
                int step;
                
                half4 result = half4(1.0,1.0,1.0,1.0);
                
                UNITY_LOOP
                for (step = 1; step<=maxStep; step++)
                {
                    lastSamplePosVS = samplePosVS;
                    samplePosVS += sampleNormalizeVector*stepLength;
                    sampleClipPos = mul((float3x3)unity_CameraProjection, samplePosVS);
                    sampleScreenPos = (sampleClipPos.xy / sampleClipPos.z) * 0.5 + 0.5;
                    
                    if (sampleScreenPos.x>1 || sampleScreenPos.y >1)
                    {
                        //超出屏幕直接剔除
                        break;
                    }
                    
                    float sampleRawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp,sampleScreenPos).r;
                    float sampleLinearEyeDepth = LinearEyeDepth(sampleRawDepth,_ZBufferParams);

                    //判定成功
                    if ((sampleLinearEyeDepth<-samplePosVS.z))
                    {
                        float distance = (-samplePosVS.z)-sampleLinearEyeDepth;
                        
                        if (distance<_MinDistance)
                        {
                            //找到
                            float2 reflectScreenPos = sampleScreenPos;
                            half3 albedo_reflect =  SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, reflectScreenPos);
                            result.rgb = albedo_reflect*_BaseColor;
                            return result;
                        }
                        else
                        {
                            //未找到
                            stepLength *= 0.5f;
                            samplePosVS = lastSamplePosVS;
                        }
                    }
                }
                
                result = half4(0.0,0.0,0.0,1.0);
                return result;
            }

            //二分搜索SSR + Jitter Dither
            static half dither[16] =
            {
                0.0, 0.5, 0.125, 0.625,
                0.75, 0.25, 0.875, 0.375,
                0.187, 0.687, 0.0625, 0.562,
                0.937, 0.437, 0.812, 0.312
            };
            
            half4 ScreenSpaceReflection_BinarySearch_JitterDither(Varyings i)
            {
                float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp, i.texcoord).r;
                float linear01Depth = Linear01Depth(rawDepth,_ZBufferParams);
                float3 posVS = ReconstructViewPositionFromDepth(i.texcoord,linear01Depth);
                float3 nDirWS = SAMPLE_TEXTURE2D(_CameraNormalsTexture,sampler_PointClamp,i.texcoord).xyz;
                float3 nDirVS = TransformWorldToViewNormal(nDirWS);
                float3 sampleNormalizeVector = normalize(reflect(normalize(posVS),nDirVS));
                float3 samplePosVS = posVS;
                float3 lastSamplePosVS = posVS;
                float stepLength = _MaxStepLength;

                
                
                int maxStep = 64;
                float3 sampleClipPos;
                float2 sampleScreenPos = i.texcoord.xy;
                int step;
                half4 result = half4(1.0,1.0,1.0,1.0);
                
                UNITY_LOOP
                for (step = 1; step<=maxStep; step++)
                {
                    
                    lastSamplePosVS = samplePosVS;
                    float2 ditherUV = fmod(sampleScreenPos*_ScreenParams, 4);  
                    float jitter = sin(dither[ditherUV.x * 4 + ditherUV.y]*2*PI)*_DitherIntensity;
                    samplePosVS += sampleNormalizeVector*stepLength;
                    float3 realSamplePosVS = samplePosVS + jitter*sampleNormalizeVector*stepLength;
                    sampleClipPos = mul((float3x3)unity_CameraProjection, realSamplePosVS);
                    sampleScreenPos = (sampleClipPos.xy / sampleClipPos.z) * 0.5 + 0.5;

                    if (sampleScreenPos.x>1 || sampleScreenPos.y >1)
                    {
                        //超出屏幕直接剔除
                        break;
                    }
                    
                    float sampleRawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp,sampleScreenPos).r;
                    float sampleLinearEyeDepth = LinearEyeDepth(sampleRawDepth,_ZBufferParams);

                    //判定成功
                    if ((sampleLinearEyeDepth<-realSamplePosVS.z))
                    {
                        float distance = (-realSamplePosVS.z)-sampleLinearEyeDepth;
                        
                        if (distance<_MinDistance)
                        {
                            //找到
                            float2 reflectScreenPos = sampleScreenPos;
                            half3 albedo_reflect =  SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, reflectScreenPos);
                            result.rgb = albedo_reflect*_BaseColor;
                            return result;
                        }
                        else
                        {
                            //未找到
                            stepLength *= 0.5f;
                            samplePosVS = lastSamplePosVS;
                        }
                    }
                }
                
                result = half4(0.0,0.0,0.0,1.0);
                return result;
            }

            //逐像素SSR
            half4 ScreenSpaceReflection_Efficient(Varyings i)
            {
                float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp, i.texcoord).r;
                float linear01Depth = Linear01Depth(rawDepth,_ZBufferParams);
                float3 posVS = ReconstructViewPositionFromDepth(i.texcoord,linear01Depth);
                float3 nDirWS = SAMPLE_TEXTURE2D(_CameraNormalsTexture,sampler_PointClamp,i.texcoord).xyz;
                float3 nDirVS = TransformWorldToViewNormal(nDirWS);
                float3 sampleNormalizeVector = normalize(reflect(normalize(posVS),nDirVS));

                float maxReflectLength = _MaxReflectLength;
                float3 startSamplePosVS = posVS;

                
                //剔除近裁切面的值
                if ((posVS.z + sampleNormalizeVector.z*maxReflectLength)>=_ProjectionParams.y)
                {
                    maxReflectLength = (-_ProjectionParams.y - posVS.z)/sampleNormalizeVector.z;
                    startSamplePosVS = posVS+_ProjectionParams.y*sampleNormalizeVector;
                }
                
                float4 startSampleClipPos = mul(unity_CameraProjection, float4(startSamplePosVS,0.0));
                float k_start = rcp(startSampleClipPos.w);
                float4 startSampleClipPos0 = startSampleClipPos*k_start;
                float2 startNDCPos = startSampleClipPos.xy*k_start;
                float2 startSampleScreenPos = startNDCPos*0.5+0.5;
                
                float3 endSamplePosVS = startSamplePosVS+maxReflectLength*sampleNormalizeVector;
                float4 endSampleClipPos = mul(unity_CameraProjection, float4(endSamplePosVS,0.0));
                float k_end = rcp(endSampleClipPos.w);
                float4 endSampleClipPos0 = endSampleClipPos*k_end;
                float2 endNDCPos = endSampleClipPos.xy*k_end;
                float2 endSampleScreenPos = endNDCPos * 0.5 + 0.5;
                
                float2 sampleScreenPos = startSampleScreenPos;
                float2 screenParams = _ScreenParams.xy;
                float2 samplePixelPos = sampleScreenPos*_ScreenParams.xy;
                float realSamplePixelPosY = sampleScreenPos.y*_ScreenParams.y;
                
                
                float2 A = startSampleScreenPos*_ScreenParams.xy;
                float2 B = endSampleScreenPos*_ScreenParams.xy;

                int deltaPixel = _DeltaPixel;
                float maxStep = abs(B.x - A.x)/deltaPixel;
                float slope = (B.y- A.y) / maxStep;
                float deltaX = (B.x - A.x) / maxStep;
                float deltaY = slope;

                
                //简便计算,若斜率绝对值大于1，则交换X轴和Y轴
                bool needSwapXY = abs(slope)>1;
                if (needSwapXY)
                {
                    float temp = A.x;
                    A.x = A.y;
                    A.y = temp;
                    
                    temp = B.x;
                    B.x = B.y;
                    B.y = temp;
                    
                    maxStep = abs(B.x - A.x)/deltaPixel;
                    slope = (B.y- A.y) / maxStep;
                    deltaX = (B.x - A.x) / maxStep;
                    deltaY = slope;
                }
                
                float stepLimit = clamp(maxStep,0,1024);//防止卡顿

                half4 result = half4(0.0,0.0,0.0,1.0);
                
                UNITY_LOOP
                for (int step = 0; step<stepLimit; step++)
                {
                    if (!needSwapXY)
                    {
                        samplePixelPos.x += deltaX;
                        realSamplePixelPosY += deltaY;
                    }
                    else
                    {
                        samplePixelPos.x += deltaY;
                        realSamplePixelPosY += deltaX;
                    }
                    
                    samplePixelPos.y = round(realSamplePixelPosY);
                    sampleScreenPos = samplePixelPos/screenParams;

                    
                    if (sampleScreenPos.x>1 || sampleScreenPos.y >1)
                    {
                        //超出屏幕直接剔除
                        break;
                    }
                    
                    float sampleRawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp,sampleScreenPos).r;
                    float sampleLinearEyeDepth = LinearEyeDepth(sampleRawDepth,_ZBufferParams);
                    float t = step/maxStep;
                    float k = lerp(k_start,k_end,t);
                    //float2 realNDCPos = sampleScreenPos*2-1;
                    float4 realClipPos0 = lerp(startSampleClipPos0,endSampleClipPos0,t);
                    float4 realClipPos = realClipPos0/k;
                    float3 realPosVS = mul(unity_CameraInvProjection,realClipPos);
                    
                    if ((sampleLinearEyeDepth<-realPosVS.z)&&(-realPosVS.z<(sampleLinearEyeDepth+_Thickness)))
                    {
                        float2 reflectScreenPos = sampleScreenPos;
                        half3 albedo_reflect =  SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, reflectScreenPos);
                        result.rgb = albedo_reflect*_BaseColor;
                        break;
                    }
                    
                }
                
                return result;
                
                
                /*
                float deltaX = 1;
                float deltaY = (B.y- A.y) / (B.x - A.x);
                */

                //划线算法
                /*
                float2 A = float2(0.5,0)*_ScreenParams.xy;
                float2 B = float2(0.2,1)*_ScreenParams.xy;
                float2 screenPixelPos = i.texcoord*_ScreenParams.xy;
                
                float k = (B.y- A.y) / (B.x - A.x);
                float b = B.y-k*B.x;

                float RoundY = round(k*screenPixelPos.x+b);
                
                half4 result = half4(0,0,0,1);
                
                float bias = 0.6f;
                float width = 0.0f;
                result = step(screenPixelPos.y,RoundY+width+bias)*step(RoundY,screenPixelPos.y+width+bias);
                return result;
                */
            }

            //逐像素SSR + Jitter Dither
            half4 ScreenSpaceReflection_Efficient_JitterDither(Varyings i)
            {
                float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp, i.texcoord).r;
                float linear01Depth = Linear01Depth(rawDepth,_ZBufferParams);
                float3 posVS = ReconstructViewPositionFromDepth(i.texcoord,linear01Depth);
                float3 nDirWS = SAMPLE_TEXTURE2D(_CameraNormalsTexture,sampler_PointClamp,i.texcoord).xyz;
                float3 nDirVS = TransformWorldToViewNormal(nDirWS);
                float3 sampleNormalizeVector = normalize(reflect(normalize(posVS),nDirVS));

                float maxReflectLength = _MaxReflectLength;
                float3 startSamplePosVS = posVS;

                
                //剔除近裁切面的值
                if ((posVS.z + sampleNormalizeVector.z*maxReflectLength)>=_ProjectionParams.y)
                {
                    maxReflectLength = (-_ProjectionParams.y - posVS.z)/sampleNormalizeVector.z;
                    startSamplePosVS = posVS+_ProjectionParams.y*sampleNormalizeVector;
                }
                
                float4 startSampleClipPos = mul(unity_CameraProjection, float4(startSamplePosVS,0.0));
                float k_start = rcp(startSampleClipPos.w);
                float4 startSampleClipPos0 = startSampleClipPos*k_start;
                float2 startNDCPos = startSampleClipPos.xy*k_start;
                float2 startSampleScreenPos = startNDCPos*0.5+0.5;
                
                float3 endSamplePosVS = startSamplePosVS+maxReflectLength*sampleNormalizeVector;
                float4 endSampleClipPos = mul(unity_CameraProjection, float4(endSamplePosVS,0.0));
                float k_end = rcp(endSampleClipPos.w);
                float4 endSampleClipPos0 = endSampleClipPos*k_end;
                float2 endNDCPos = endSampleClipPos.xy*k_end;
                float2 endSampleScreenPos = endNDCPos * 0.5 + 0.5;
                
                float2 sampleScreenPos = startSampleScreenPos;
                float2 screenParams = _ScreenParams.xy;
                float2 samplePixelPos = sampleScreenPos*_ScreenParams.xy;
                float samplePixelPosY = sampleScreenPos.y*_ScreenParams.y;
                
                
                float2 A = startSampleScreenPos*_ScreenParams.xy;
                float2 B = endSampleScreenPos*_ScreenParams.xy;

                int deltaPixel = _DeltaPixel;
                float maxStep = abs(B.x - A.x)/deltaPixel;
                float slope = (B.y- A.y) / maxStep;
                float deltaX = (B.x - A.x) / maxStep;
                float deltaY = slope;

                
                //简便计算,若斜率绝对值大于1，则交换X轴和Y轴
                bool needSwapXY = abs(slope)>1;
                if (needSwapXY)
                {
                    float temp = A.x;
                    A.x = A.y;
                    A.y = temp;
                    
                    temp = B.x;
                    B.x = B.y;
                    B.y = temp;
                    
                    maxStep = abs(B.x - A.x)/deltaPixel;
                    slope = (B.y- A.y) / maxStep;
                    deltaX = (B.x - A.x) / maxStep;
                    deltaY = slope;
                }
                
                float stepLimit = clamp(maxStep,0,1024);//防止卡顿

                half4 result = half4(0.0,0.0,0.0,1.0);
                UNITY_LOOP
                for (int step = 0; step<stepLimit; step++)
                {
                    float2 ditherUV = fmod(samplePixelPos, 4);
                    float ditherValue = sin(dither[ditherUV.x * 4 + ditherUV.y]*2*PI)*_DitherIntensity*0.33f;
                    float2 ditherXY;
                    if (!needSwapXY)
                    {
                        ditherXY.x = round(ditherValue*deltaX);
                        ditherXY.y = round(ditherValue*deltaY);
                        samplePixelPos.x += deltaX;
                        samplePixelPosY += deltaY;
                    }
                    else
                    {
                        ditherXY.x = round(ditherValue*deltaY);
                        ditherXY.y = round(ditherValue*deltaX);
                        samplePixelPos.x += deltaY;
                        samplePixelPosY += deltaX;
                    }

                    
                    samplePixelPos.y = round(samplePixelPosY);
                    sampleScreenPos = (samplePixelPos+ditherXY)/screenParams;
                    
                    if (sampleScreenPos.x>1 || sampleScreenPos.y >1)
                    {
                        //超出屏幕直接剔除
                        break;
                    }
                    
                    float sampleRawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp,sampleScreenPos).r;
                    float sampleLinearEyeDepth = LinearEyeDepth(sampleRawDepth,_ZBufferParams);
                    float t = step/maxStep;
                    float k = lerp(k_start,k_end,t);
                    //float2 realNDCPos = sampleScreenPos*2-1;
                    float4 realClipPos0 = lerp(startSampleClipPos0,endSampleClipPos0,t);
                    float4 realClipPos = realClipPos0/k;
                    float3 realPosVS = mul(unity_CameraInvProjection,realClipPos);
                    
                    if ((sampleLinearEyeDepth<-realPosVS.z)&&(-realPosVS.z<(sampleLinearEyeDepth+_Thickness)))
                    {
                        float2 reflectScreenPos = sampleScreenPos;
                        half3 albedo_reflect =  SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, reflectScreenPos);
                        result.rgb = albedo_reflect*_BaseColor;
                        break;
                    }
                    
                }
                
                return result;
            }

            //Hiz 算法 SSR
            float SampleDepthTexture_Hiz(float2 screenPos, int mipLevel)
            {
                float rawDepth;
                switch (mipLevel)
                {
                    case 1:
                        rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp, screenPos).r;
                        break;
                    case 2:
                        rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture_MipLevel_2,sampler_PointClamp, screenPos).r;
                        break;
                    case 3:
                        rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture_MipLevel_3,sampler_PointClamp, screenPos).r;
                        break;
                    case 4:
                        rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture_MipLevel_4,sampler_PointClamp, screenPos).r;
                        break;
                    case 5:
                        rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture_MipLevel_5,sampler_PointClamp, screenPos).r;
                        break;
                    case 6:
                        rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture_MipLevel_6,sampler_PointClamp, screenPos).r;
                        break;
                    default:
                        rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp, screenPos).r;
                        break;
                }
                return rawDepth;
            }

            
            half4 ScreenSpaceReflection_Hiz(Varyings i)
            {
                 float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp, i.texcoord).r;
                float linear01Depth = Linear01Depth(rawDepth,_ZBufferParams);
                float3 posVS = ReconstructViewPositionFromDepth(i.texcoord,linear01Depth);
                float3 nDirWS = SAMPLE_TEXTURE2D(_CameraNormalsTexture,sampler_PointClamp,i.texcoord).xyz;
                float3 nDirVS = TransformWorldToViewNormal(nDirWS);
                float3 sampleNormalizeVector = normalize(reflect(normalize(posVS),nDirVS));
                float3 lastSamplePosVS = posVS;
                float3 samplePosVS = posVS;
                float stepLength = _StepLength;
                int maxStep = 128;
                float3 sampleClipPos;
                float2 sampleScreenPos;
                int step;
                int mipLevel = 1;
                
                half4 result = half4(1.0,1.0,1.0,1.0);

                UNITY_LOOP
                for (step = 1; step<=maxStep; step++)
                {
                    samplePosVS += sampleNormalizeVector*stepLength;
                    sampleClipPos = mul((float3x3)unity_CameraProjection, samplePosVS);
                    sampleScreenPos = (sampleClipPos.xy / sampleClipPos.z) * 0.5 + 0.5;
                    float sampleRawDepth = SampleDepthTexture_Hiz(sampleScreenPos,6).r;
                    float sampleLinearEyeDepth = LinearEyeDepth(sampleRawDepth,_ZBufferParams);
                    if ((sampleLinearEyeDepth<-samplePosVS.z)&&(-samplePosVS.z<(sampleLinearEyeDepth+_Thickness)))
                    {
                        float2 reflectScreenPos = sampleScreenPos;
                        half3 albedo_reflect =  SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, reflectScreenPos);
                        result.rgb = albedo_reflect*_BaseColor;
                        return result;
                    }
                }
                
                result = half4(0.0,0.0,0.0,1.0);
                return result;
                
                UNITY_LOOP
                for (step = 1; step<=maxStep; step++)
                {
                    lastSamplePosVS = samplePosVS;

                    //步进
                    samplePosVS += sampleNormalizeVector*stepLength;
                    sampleClipPos = mul((float3x3)unity_CameraProjection, samplePosVS);
                    sampleScreenPos = (sampleClipPos.xy / sampleClipPos.z) * 0.5 + 0.5;
                    float sampleRawDepth = SampleDepthTexture_Hiz(sampleScreenPos,mipLevel).r;
                    float sampleLinearEyeDepth = LinearEyeDepth(sampleRawDepth,_ZBufferParams);

                    //通过判定
                    if ((sampleLinearEyeDepth<-samplePosVS.z))
                    {
                        if (mipLevel<=1)
                        {
                            if (-samplePosVS.z<(sampleLinearEyeDepth+_Thickness))
                            {
                                float2 reflectScreenPos = sampleScreenPos;
                                half3 albedo_reflect =  SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, reflectScreenPos);
                                result.rgb = albedo_reflect*_BaseColor;
                                return result;
                            }
                        }
                        else
                        {
                            samplePosVS = lastSamplePosVS;
                            stepLength *= 0.5f;
                            mipLevel--;
                        }
                    }
                    else
                    {
                        stepLength *= 2;
                        if (mipLevel<6)
                        {
                            mipLevel++;
                        }
                        
                    }
                }
                
                result = half4(0.0,0.0,0.0,1.0);
                return result;
            }
            
            
            half4 frag (Varyings i) : SV_TARGET
            {
                
                half4 result = half4(1,1,1,1);

                #ifdef SIMPLE_VS
                    result = ScreenSpaceReflection_Simple(i);
                #endif
                
                #ifdef BINARY_SEARCH_VS
                    result = ScreenSpaceReflection_BinarySearch(i);
                #endif

                #ifdef BINARY_SEARCH_JITTER_VS
                    result = ScreenSpaceReflection_BinarySearch_JitterDither(i);
                #endif
                
                #ifdef EFFICIENT_SS
                    result = ScreenSpaceReflection_Efficient(i);
                #endif
                
                #ifdef EFFICIENT_JITTER_SS
                    result = ScreenSpaceReflection_Efficient_JitterDither(i);
                #endif

                #ifdef HIZ_VS
                    result = ScreenSpaceReflection_Hiz(i);
                #endif
                
                
                return result;
            }
            
            ENDHLSL
        }
        
    }
}