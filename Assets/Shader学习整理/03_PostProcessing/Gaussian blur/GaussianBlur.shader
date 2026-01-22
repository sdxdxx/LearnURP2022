Shader "URP/PostProcessing/GaussianBlur"
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
        
        
        //Blur Vertical
        Pass
        {
            Cull Off 
            ZWrite Off
            
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
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float _BlurSize;
            //float4 _CameraOpaqueTexture_ST;
            float4 _MainTex_ST;
            float4 _BlitTexture_TexelSize;
            //----------变量声明结束-----------
            CBUFFER_END
            
            
            half4 frag (Varyings i) : SV_TARGET
            {
                float2 uv = i.texcoord;
                //设置垂直方向的采样坐标
                float2 uv_vertical[5];
                uv_vertical[0] = uv + float2(0.0, _BlitTexture_TexelSize.y * 2.0) * _BlurSize;
                uv_vertical[1] = uv + float2(0.0, _BlitTexture_TexelSize.y * 1.0) * _BlurSize;
                uv_vertical[2] = uv;
                uv_vertical[3] = uv - float2(0.0, _BlitTexture_TexelSize.y * 1.0) * _BlurSize;
                uv_vertical[4] = uv - float2(0.0, _BlitTexture_TexelSize.y * 2.0) * _BlurSize;
                
                //weight
                float weight[5] = { 0.0545,0.2442,0.4026, 0.2442, 0.0545};

                //中心纹理*权重
                half3 sum = 0;
                //上下/左右 的2个纹理*权重
                sum += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,uv_vertical[0]).rgb * weight[0];
                sum += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,uv_vertical[1]).rgb * weight[1];
                sum += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,uv_vertical[2]).rgb * weight[2];
                sum += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,uv_vertical[3]).rgb * weight[3];
                sum += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,uv_vertical[4]).rgb * weight[4];
                half4 col = half4(sum,0);
                return col*_BaseColor;
            }
            
            ENDHLSL
        }

        //Blur Horizontal
        Pass
        {
            Cull Off 
            ZWrite Off
            
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
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float _BlurSize;
            //float4 _CameraOpaqueTexture_ST;
            float4 _MainTex_ST;
            float4 _BlitTexture_TexelSize;
            //----------变量声明结束-----------
            CBUFFER_END
            
            
            half4 frag (Varyings i) : SV_TARGET
            {
                
                
                float2 uv = i.texcoord;
                //设置水平方向的采样坐标
                float2 uv_horizontal[5];
                uv_horizontal[0] = uv + float2(_BlitTexture_TexelSize.x * 2.0, 0.0) * _BlurSize;
                uv_horizontal[1] = uv + float2(_BlitTexture_TexelSize.x * 1.0, 0.0) * _BlurSize;
                uv_horizontal[2] = uv;
                uv_horizontal[3] = uv - float2(_BlitTexture_TexelSize.x * 1.0, 0.0) * _BlurSize;
                uv_horizontal[4] = uv - float2(_BlitTexture_TexelSize.x * 2.0, 0.0) * _BlurSize;

                //weight
                float weight[5] = { 0.0545,0.2442,0.4026, 0.2442, 0.0545};

                //中心纹理*权重
                half3 sum = 0;
                //上下/左右 的2个纹理*权重
                sum += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,uv_horizontal[0]).rgb * weight[0];
                sum += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,uv_horizontal[1]).rgb * weight[1];
                sum += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,uv_horizontal[2]).rgb * weight[2];
                sum += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,uv_horizontal[3]).rgb * weight[3];
                sum += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,uv_horizontal[4]).rgb * weight[4];
                half4 col = half4(sum,0);
                return col*_BaseColor;
            }
            
            ENDHLSL
        }
    }
}