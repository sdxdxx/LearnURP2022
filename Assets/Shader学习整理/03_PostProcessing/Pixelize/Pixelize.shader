Shader "URP/PostProcessing/Pixelize"
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
        
        pass
        {
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag
            #define DOWN_SAMPLE_VALUE 0

            #pragma shader_feature IS_ORTH_CAM

           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
           #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            #include  "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_PixelizeMask);
            SAMPLER(sampler_PixelizeMask);
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            //float4 _CameraOpaqueTexture_ST;
            float4 _MainTex_ST;
            int _DownSampleValue;
            //----------变量声明结束-----------
            CBUFFER_END

            
            half4 frag (Varyings i) : SV_TARGET
            {
                int downSampleValue = pow(2,_DownSampleValue);
                float2 screenPos = i.texcoord.xy;
                int2 pixelPos = round(screenPos*_ScreenParams.xy);
                int2 downSamplePixelPos = int2(pixelPos.x/downSampleValue,pixelPos.y/downSampleValue);
                
                
                float rawMask = SAMPLE_TEXTURE2D(_PixelizeMask,sampler_PixelizeMask,screenPos).r;
                float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp, screenPos).r;
                float maskRawDepth = SAMPLE_TEXTURE2D(_PixelizeMask,sampler_PointClamp,screenPos).g;
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
                    bias = 0.004;
                #endif

                float clearObjectMask_Reverse = step(mask01Depth,linear01Depth+bias);
                
                half4 pixelizeColor = half4(0,0,0,0.0f);
                float mask = 0;
                for (int i = 0; i<downSampleValue; i++)
                {
                    for (int j = 0; j<downSampleValue;j++)
                    {
                        float2 sampleUV = (downSamplePixelPos*downSampleValue+float2(i,j))/_ScreenParams.xy;
                        pixelizeColor += SAMPLE_TEXTURE2D(_BlitTexture, sampler_PointClamp, sampleUV);
                        mask += SAMPLE_TEXTURE2D(_PixelizeMask,sampler_PixelizeMask,sampleUV).r;
                    }
                }
                
                half4 albedo =  SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, screenPos);
                pixelizeColor /= downSampleValue*downSampleValue; 
                mask /= downSampleValue*downSampleValue;
                mask = step(0.001f,mask)*clearObjectMask_Reverse;
                
                half4 result = lerp(albedo,pixelizeColor,mask);
                return result;
            }
            
            ENDHLSL
        }
    }
}