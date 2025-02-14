Shader "URP/PostProcessing/HIZ"
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

            //----------贴图声明开始-----------
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            float4 _SourceSize1;
            float4 _SourceSize2;
            float4 _SourceSize3;
            float4 _SourceSize4;
            float4 _SourceSize5;
            //----------变量声明结束-----------
            CBUFFER_END
            
            float4 GetSource(float2 uv, float2 offset = 0.0, float4 sourceSize = 1.0)
            {
                offset *= 1+sourceSize.zw;
                return SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearRepeat, uv + offset);
            }

            float GetMinDepth(float2 uv, float4 sourceSize)
            {
                float4 minDepth = float4(
                    GetSource(uv, float2(-1, -1), sourceSize).r,
                    GetSource(uv, float2(-1, 1),  sourceSize).r,
                    GetSource(uv, float2(1, -1),  sourceSize).r,
                    GetSource(uv, float2(1, 1),   sourceSize).r
                );

                float rawDepth = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearRepeat, uv);
                float temp = max(max(minDepth.r, minDepth.g), max(minDepth.b, minDepth.a));
                float result = max(temp,rawDepth);
                return result;
            }
            
            
        ENDHLSL
        
        //SampleDepthTexture pass0
        pass
        {
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag
            
            float4 frag (Varyings i) : SV_TARGET
            {
                float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp,i.texcoord).r;
                return rawDepth;
            }
            
            ENDHLSL
        }

        //GenerateDepthMip2  pass1
         pass
        {
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag
            
            float4 frag (Varyings i) : SV_TARGET
            {
                float result = GetMinDepth(i.texcoord,_SourceSize1);
                return result;
            }
            
            ENDHLSL
        }

        //GenerateDepthMip3  pass2
         pass
        {
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag
            
            float4 frag (Varyings i) : SV_TARGET
            {
                float result = GetMinDepth(i.texcoord,_SourceSize2);
                return result;
            }
            
            ENDHLSL
        }

        //GenerateDepthMip4  pass3
         pass
        {
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag
            
            float4 frag (Varyings i) : SV_TARGET
            {
                float result = GetMinDepth(i.texcoord,_SourceSize3);
                return result;
            }
            
            ENDHLSL
        }

         //GenerateDepthMip5 pass4
         pass
        {
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag
            
            float4 frag (Varyings i) : SV_TARGET
            {
                float result = GetMinDepth(i.texcoord,_SourceSize4);
                return result;
            }
            
            ENDHLSL
        }

        //GenerateDepthMip6  pass5
         pass
        {
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag
            
            float4 frag (Varyings i) : SV_TARGET
            {
                float result = GetMinDepth(i.texcoord,_SourceSize5);
                return result;
            }
            
            ENDHLSL
        }


    }
}