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
                
                half4 pixelizeColor = half4(0,0,0,1.0f);
                float mask = 0;
                for (int i = 0; i<downSampleValue; i++)
                {
                    for (int j = 0; j<downSampleValue;j++)
                    {
                        float2 sampleUV = (downSamplePixelPos*downSampleValue+float2(i,j))/_ScreenParams.xy;
                        pixelizeColor.rgb += SAMPLE_TEXTURE2D(_BlitTexture, sampler_PointClamp, sampleUV);
                        mask += SAMPLE_TEXTURE2D(_PixelizeMask,sampler_PixelizeMask,sampleUV).r;
                    }
                }
                
                half4 albedo =  SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, screenPos);
                float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp, screenPos).r;
                float linearEyeDepth = LinearEyeDepth(rawDepth,_ZBufferParams);
                float maskEyeDepth = SAMPLE_TEXTURE2D(_PixelizeMask,sampler_PointClamp,screenPos).g;
                
                //return  maskEyeDepth;
                //return step(maskEyeDepth,linearEyeDepth+0.01);
                
                pixelizeColor.rgb /= downSampleValue*downSampleValue; 
                mask /= downSampleValue*downSampleValue;
                mask = step(0.01f,mask)*step(maskEyeDepth,linearEyeDepth+0.01);
                half4 result = lerp(albedo,pixelizeColor,mask);
                
                return result;
            }
            
            ENDHLSL
        }
    }
}