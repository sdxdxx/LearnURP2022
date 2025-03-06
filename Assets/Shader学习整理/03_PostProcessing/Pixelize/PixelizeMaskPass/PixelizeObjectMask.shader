Shader "URP/PostProcessing/PixelizeObjectMask"
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
        
       //sobel
        pass
        {
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

            #pragma shader_feature IS_ORTH_CAM
            #pragma shader_feature ENABLE_POINT
            #pragma shader_feature ENABLE_CONTRAST_AND_SATURATION

           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
           #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            #include  "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_PixelizeObjectMask);
            TEXTURE2D(_CameraDepthTexture);
            //----------贴图声明结束-----------
            
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

             float CalculateMaskSobelEdge(float2 screenPos, float size)
            {
                float3 lum = float3(0.2125,0.7154,0.0721);//转化为luminance亮度值
			    //获取当前点的周围的点
			    //并与luminance点积，求出亮度值（黑白图）
			    float mc00 = dot(SAMPLE_TEXTURE2D(_PixelizeObjectMask,sampler_PointClamp, screenPos-float2(1,1)/size).aaa, lum);
			    float mc10 = dot(SAMPLE_TEXTURE2D(_PixelizeObjectMask,sampler_PointClamp, screenPos-float2(0,1)/size).aaa, lum);
			    float mc20 = dot(SAMPLE_TEXTURE2D(_PixelizeObjectMask,sampler_PointClamp, screenPos-float2(-1,1)/size).aaa, lum);
			    float mc01 = dot(SAMPLE_TEXTURE2D(_PixelizeObjectMask,sampler_PointClamp, screenPos-float2(1,0)/size).aaa, lum);
			    float mc11mc = dot(SAMPLE_TEXTURE2D(_PixelizeObjectMask,sampler_PointClamp, screenPos).aaa, lum);
			    float mc21 = dot(SAMPLE_TEXTURE2D(_PixelizeObjectMask,sampler_PointClamp, screenPos-float2(-1,0)/size).aaa, lum);
			    float mc02 = dot(SAMPLE_TEXTURE2D(_PixelizeObjectMask,sampler_PointClamp, screenPos-float2(1,-1)/size).aaa, lum);
			    float mc12 = dot(SAMPLE_TEXTURE2D(_PixelizeObjectMask,sampler_PointClamp, screenPos-float2(0,-1)/size).aaa, lum);
			    float mc22 = dot(SAMPLE_TEXTURE2D(_PixelizeObjectMask,sampler_PointClamp, screenPos-float2(-1,-1)/size).aaa, lum);
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
                float2 screenPos = input.texcoord.xy;
                //计算当前像素深度值和遮罩
                float4 pixelizeObjectParam = SAMPLE_TEXTURE2D(_PixelizeObjectMask,sampler_PointClamp,screenPos);
            	float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp, screenPos).r;
                float maskRawDepth = pixelizeObjectParam.r;
            	float clearObjectMask_Reverse = CalculateClearObjectMaskReverse(rawDepth,maskRawDepth);
            	
            	float rawMask = step(pixelizeObjectParam.a,1-0.0000001);
            	float inlineWidthControl = pixelizeObjectParam.g;
                float sobel = CalculateMaskSobelEdge(screenPos,lerp(2000,500,inlineWidthControl))*rawMask;
            	half4 result = half4(sobel,clearObjectMask_Reverse,0,1.0);
                return result;
            }
            ENDHLSL
        }
    }
}