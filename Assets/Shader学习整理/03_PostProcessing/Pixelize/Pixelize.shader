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
            
            half4 frag (Varyings input) : SV_TARGET
            {
                //计算采样参数
                int downSampleValue = pow(2,_DownSampleValue);
                float2 screenPos = input.texcoord.xy;
                int2 pixelPos = round(screenPos*_ScreenParams.xy);
                int2 downSamplePixelPos = int2(pixelPos.x/downSampleValue,pixelPos.y/downSampleValue);

                //计算当前像素深度值和遮罩
                float rawMask = SAMPLE_TEXTURE2D(_PixelizeMask,sampler_PointClamp,screenPos).r;
                float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp, screenPos).r;
                float maskRawDepth = SAMPLE_TEXTURE2D(_PixelizeMask,sampler_PointClamp,screenPos).g;
                
                half4 pixelizeColor = half4(0,0,0,0.0f);
                float mask = 0;
                float pixelRawDepth = rawDepth;
                float pixelMaskRawDepth = maskRawDepth;
                
                float2 lastSampleUV = screenPos;
                UNITY_LOOP
                for (int i = 0; i<downSampleValue; i++)
                {
                    UNITY_LOOP
                    for (int j = 0; j<downSampleValue;j++)
                    {
                        float2 sampleUV = (downSamplePixelPos*downSampleValue+float2(i,j))/_ScreenParams.xy;
                        float sampleRawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp, sampleUV).r;
                        float sampleMaskRawDepth = SAMPLE_TEXTURE2D(_PixelizeMask,sampler_PointClamp,sampleUV).g;
                        float sampleClearObjectMask_Reverse = CalculateClearObjectMaskReverse(sampleRawDepth,sampleMaskRawDepth);
                        
                        if (sampleClearObjectMask_Reverse<0.1f)
                        {
                            pixelizeColor.rgb += SAMPLE_TEXTURE2D(_BlitTexture,sampler_PointClamp,lastSampleUV);
                            pixelizeColor.a += 0.8;
                        }
                        else
                        {
                            lastSampleUV = sampleUV;
                            pixelizeColor.rgb += SAMPLE_TEXTURE2D(_BlitTexture,sampler_PointClamp,sampleUV);
                            pixelizeColor.a += 1;
                        }
                        pixelRawDepth = max(pixelRawDepth,SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp, lastSampleUV).r);
                        pixelMaskRawDepth = max(pixelMaskRawDepth,SAMPLE_TEXTURE2D(_PixelizeMask,sampler_PointClamp,lastSampleUV).g);
                        mask += SAMPLE_TEXTURE2D(_PixelizeMask,sampler_PointClamp,sampleUV).r;
                    }
                }
                
                half4 albedo =  SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, screenPos);
                pixelizeColor /= downSampleValue*downSampleValue;
                mask /= downSampleValue*downSampleValue;
                
                
                float realPixelDepth = max(rawDepth,pixelRawDepth);
                float realPixelMaskRawDepth = max(maskRawDepth,pixelMaskRawDepth);
                
                float clearObjectMask_Reverse = CalculateClearObjectMaskReverse(realPixelDepth,realPixelMaskRawDepth);
                
                mask = step(0.001f,mask)*clearObjectMask_Reverse;

                if (_DownSampleValue == 0 )
                {
                    mask = rawMask;
                }
                
                
                
                float realMask = mask*pixelizeColor.a;

                float edgePixelMask = 1-step(realMask,rawMask);
                
                
                half3 finalRGB = lerp(albedo.rgb,pixelizeColor.rgb,realMask);
                half4 result = half4(finalRGB,albedo.a);

                return result;
            }
            
            ENDHLSL
        }
    }
}