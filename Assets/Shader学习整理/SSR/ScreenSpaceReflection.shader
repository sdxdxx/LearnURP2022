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
        
        pass
        {
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag
            #pragma shader_feature SIMPLE_VS //基础视角空间SSR
            #pragma shader_feature BINARY_SEARCH_VS //视空间二分搜索SSR
            #pragma shader_feature EFFICIENT_SS //屏幕空间SSR
            
            
            //----------贴图声明开始-----------
            TEXTURE2D(_CameraOpaqueTexture);//获取到摄像机渲染画面的Texture
            SAMPLER(sampler_CameraOpaqueTexture);
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_CameraNormalsTexture);
            SAMPLER(sampler_CameraNormalsTexture);
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

            //屏幕空间光栅化SSR
            half4 ScreenSpaceReflection_Efficient(Varyings i)
            {
                float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp, i.texcoord).r;
                float linear01Depth = Linear01Depth(rawDepth,_ZBufferParams);
                float3 posVS = ReconstructViewPositionFromDepth(i.texcoord,linear01Depth);
                float3 nDirWS = SAMPLE_TEXTURE2D(_CameraNormalsTexture,sampler_PointClamp,i.texcoord).xyz;
                float3 nDirVS = TransformWorldToViewNormal(nDirWS);
                float3 sampleNormalizeVector = normalize(reflect(normalize(posVS),nDirVS));
                float2 sampleScreenPos = i.texcoord;
                float2 screenParams = _ScreenParams.xy;
                float2 samplePixelPos = i.texcoord*_ScreenParams.xy;
                float realSamplePixelPosY = i.texcoord.y*_ScreenParams.xy;
                float maxReflectLength = _MaxReflectLength;

                float3 startSamplePosVS = posVS;
                float3 startSampleClipPos = mul((float3x3)unity_CameraProjection, startSamplePosVS);
                float k_start = startSampleClipPos.z;
                float2 startNDCPos = i.texcoord*2-1;
                float2 startSampleScreenPos = i.texcoord;
                float3 endSamplePosVS = posVS+maxReflectLength*sampleNormalizeVector;
                float3 endSampleClipPos = mul((float3x3)unity_CameraProjection, endSamplePosVS);
                float k_end = endSampleClipPos.z;
                float2 endNDCPos = endSampleClipPos.xy / endSampleClipPos.z;
                float2 endSampleScreenPos = endNDCPos * 0.5 + 0.5;

                float2 A = startSampleScreenPos*_ScreenParams.xy;
                float2 B = endSampleScreenPos*_ScreenParams.xy;

                float slope = (B.y- A.y) / (B.x - A.x);

                float deltaX = 1*(step(B.x,A.x)*2-1);
                float deltaY = slope;
                
                //简便计算,若斜率绝对值大于1，则交换X轴和Y轴
                if (abs(slope)>1)
                {
                    float temp = A.x;
                    A.x = A.y;
                    A.y = temp;
                    
                    temp = B.x;
                    B.x = B.y;
                    B.y = temp;

                    temp = screenParams.x;
                    screenParams.x = screenParams.y;
                    screenParams.y = temp;

                    slope = rcp(slope);

                    deltaX = slope;
                    deltaY = 1*(step(B.x,A.x)*2-1);
                }
                
                int maxStep = abs(B.x - A.x);

                half4 result = half4(0.0,0.0,0.0,1.0);

                UNITY_LOOP
                for (int step = 0; step<maxStep; step++)
                {
                    samplePixelPos.x += deltaX;
                    realSamplePixelPosY += deltaY;
                    samplePixelPos.y = round(realSamplePixelPosY);
                    sampleScreenPos = samplePixelPos/screenParams;
                    float sampleRawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp,sampleScreenPos).r;
                    float sampleLinearEyeDepth = LinearEyeDepth(sampleRawDepth,_ZBufferParams);
                    float k = k_start+ (step/maxStep)*(k_end - k_start);
                    float2 realNDCPos = sampleScreenPos*2-1;
                    float3 realClipPos = float3(realNDCPos*k,k);
                    float3 realPosVS = mul((float3x3)unity_CameraInvProjection,realClipPos);
                    if ((sampleLinearEyeDepth<-realPosVS.z)&&(-realPosVS.z<(sampleLinearEyeDepth+_Thickness)))
                    {
                        float2 reflectScreenPos = sampleScreenPos;
                        half3 albedo_reflect =  SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, reflectScreenPos);
                        result.rgb = albedo_reflect*_BaseColor;
                        return result;
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
            

            
            half4 frag (Varyings i) : SV_TARGET
            {
                
                half4 result = half4(1,1,1,1);

                #ifdef SIMPLE_VS
                    result = ScreenSpaceReflection_Simple(i);
                #endif
                
                #ifdef BINARY_SEARCH_VS
                    result = ScreenSpaceReflection_BinarySearch(i);
                #endif

                #ifdef EFFICIENT_SS
                    result = ScreenSpaceReflection_Efficient(i);
                #endif
                
                
                return result;
            }
            
            ENDHLSL
        }
    }
}