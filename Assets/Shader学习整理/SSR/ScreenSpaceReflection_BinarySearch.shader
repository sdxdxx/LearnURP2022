Shader "URP/PostProcessing/ScreenSpaceReflection/BinarySearch"
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
            float _StepLength;
            float _Bias;
            //----------变量声明结束-----------
            CBUFFER_END
            
            half4 frag (Varyings i) : SV_TARGET
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
                    if ((sampleLinearEyeDepth<-samplePosVS.z)&&(-samplePosVS.z<(sampleLinearEyeDepth+_Bias)))
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
            
            ENDHLSL
        }
    }
}