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
            #pragma shader_feature ENABLE_POINT
            #pragma shader_feature ENABLE_CONTRAST_AND_SATURATION

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
            float4 _BlitTexture_TexelSize;
            int _DownSampleValue;
            float _Contrast;
            float _Saturation;
            float _PointIntensity;
            //----------变量声明结束-----------
            CBUFFER_END

             half4 GetGray (half4 inColor)
            {
	            return dot (inColor , half4 (0.299,0.587,0.114,1.0));
            }

            half3 GetGray (half3 inColor)
            {
	            return dot (inColor , half3 (0.299,0.587,0.114));
            }
            
             half4 GetContrast (half4 inColor, float contrast)
            {
	            return (inColor + (GetGray(inColor) -0.5) * contrast);
            }

            half3 GetContrast (half3 inColor, float contrast)
            {
	            return (inColor + (GetGray(inColor) -0.5) * contrast);
            }

             half4 GetSaturation (half4 inColor, float saturation)
            {
	            float average = (inColor.r + inColor.g + inColor.b) / 3;
	            inColor.rgb +=  (inColor.rgb - average) * saturation;
	            return inColor;
            }

            half3 GetSaturation (half3 inColor, float saturation)
            {
	            float average = (inColor.r + inColor.g + inColor.b) / 3;
	            inColor.rgb +=  (inColor.rgb - average) * saturation;
	            return inColor;
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

            float CalculateSobelEdge(float2 screenPos, float size)
            {
                float3 lum = float3(0.2125,0.7154,0.0721);//转化为luminance亮度值
			    //获取当前点的周围的点
			    //并与luminance点积，求出亮度值（黑白图）
			    float mc00 = dot(SAMPLE_TEXTURE2D(_BlitTexture,sampler_PointClamp, screenPos-float2(1,1)/size).rgb, lum);
			    float mc10 = dot(SAMPLE_TEXTURE2D(_BlitTexture,sampler_PointClamp, screenPos-float2(0,1)/size).rgb, lum);
			    float mc20 = dot(SAMPLE_TEXTURE2D(_BlitTexture,sampler_PointClamp, screenPos-float2(-1,1)/size).rgb, lum);
			    float mc01 = dot(SAMPLE_TEXTURE2D(_BlitTexture,sampler_PointClamp, screenPos-float2(1,0)/size).rgb, lum);
			    float mc11mc = dot(SAMPLE_TEXTURE2D(_BlitTexture,sampler_PointClamp, screenPos).rgb, lum);
			    float mc21 = dot(SAMPLE_TEXTURE2D(_BlitTexture,sampler_PointClamp, screenPos-float2(-1,0)/size).rgb, lum);
			    float mc02 = dot(SAMPLE_TEXTURE2D(_BlitTexture,sampler_PointClamp, screenPos-float2(1,-1)/size).rgb, lum);
			    float mc12 = dot(SAMPLE_TEXTURE2D(_BlitTexture,sampler_PointClamp, screenPos-float2(0,-1)/size).rgb, lum);
			    float mc22 = dot(SAMPLE_TEXTURE2D(_BlitTexture,sampler_PointClamp, screenPos-float2(-1,-1)/size).rgb, lum);
			    //根据过滤器矩阵求出GX水平和GY垂直的灰度值
			    float GX = -1 * mc00 + mc20 + -2 * mc01 + 2 * mc21 - mc02 + mc22;
			    float GY = mc00 + 2 * mc10 + mc20 - mc02 - 2 * mc12 - mc22;
		    //	float G = sqrt(GX*GX+GY*GY);//标准灰度公式
			    float G = abs(GX)+abs(GY);//近似灰度公式
    //			float th = atan(GY/GX);//灰度方向
			    float4 c = 0;
    //			c = G>th?1:0;
    //			c = G/th*2;
			    c = length(float2(GX,GY));//length的内部算法就是灰度公式的算法，欧几里得长度
                return c;
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
                
                half4 pixelizeColor = SAMPLE_TEXTURE2D(_BlitTexture,sampler_PointClamp,screenPos);
                float mask = 0;
                float pixelRawDepth = rawDepth;
                float pixelMaskRawDepth = maskRawDepth;

                float2 realSampleUV = float2(0,0);
                
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
                            realSampleUV+=lastSampleUV;
                            pixelizeColor.rgb += SAMPLE_TEXTURE2D(_BlitTexture,sampler_PointClamp,lastSampleUV);
                            pixelizeColor.a += 0.8;
                        }
                        else
                        {
                            realSampleUV+=sampleUV;
                            
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
                realSampleUV /= downSampleValue*downSampleValue;
                
                float realPixelDepth = max(rawDepth,pixelRawDepth);
                float realPixelMaskRawDepth = max(maskRawDepth,pixelMaskRawDepth);
                
                float clearObjectMask_Reverse = CalculateClearObjectMaskReverse(realPixelDepth,realPixelMaskRawDepth);

                float edgePixelMask = step(0.0001,mask)*step(mask,0.9);
                
                mask = step(0.001f,mask)*clearObjectMask_Reverse;
                
                if (_DownSampleValue == 0 )
                {
                    mask = rawMask;
                }
                
                float realMask = mask*pixelizeColor.a;
                
                #ifdef ENABLE_POINT
                half3 samplePixelizeColorRGB = SAMPLE_TEXTURE2D(_BlitTexture, sampler_PointClamp, realSampleUV);
                float sobel = step(0.9,CalculateSobelEdge(realSampleUV,2000));
                samplePixelizeColorRGB = pixelizeColor.rgb*(1-_PointIntensity)+samplePixelizeColorRGB*_PointIntensity;
                edgePixelMask = max(edgePixelMask,sobel);
                pixelizeColor.rgb = lerp(samplePixelizeColorRGB,pixelizeColor.rgb,edgePixelMask);
                #endif
                
                #ifdef ENABLE_CONTRAST_AND_SATURATION
                pixelizeColor.rgb = GetContrast(pixelizeColor.rgb,_Contrast);
                pixelizeColor.rgb = GetSaturation(pixelizeColor.rgb,_Saturation);
                #endif
                
                half3 finalRGB = lerp(albedo.rgb,pixelizeColor.rgb,realMask);
                
                half4 result = half4(finalRGB,albedo.a);

                return result;
            }
            
            ENDHLSL
        }
    }
}