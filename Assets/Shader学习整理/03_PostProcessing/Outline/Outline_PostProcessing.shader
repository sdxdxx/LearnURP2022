Shader "URP/PostProcessing/Outline"
{
    Properties
    {
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
        
        //OutlineMask
        pass
        {
            Tags{"LightMode"="OutlineMask"}
            
            Name "OutlineMask"
             
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            //----------变量声明结束-----------
            CBUFFER_END

            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            	float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 nDirWS : TEXCOORD1;
            };
            
            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                return half4(1,1,1,1);
            }
            
            ENDHLSL
        }

        pass
        {
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
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_OutlineMask);
            SAMPLER(sampler_OutlineMask);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _OutlineColor;
            float _Rate;
            //float4 _CameraOpaqueTexture_ST;
            float4 _MainTex_ST;
            float4 _CameraDepthTexture_TexelSize;
            //----------变量声明结束-----------
            CBUFFER_END
            
            half4 frag (Varyings i) : SV_TARGET
            {
                float2 uv[9];
                uv[0] = i.texcoord + _CameraDepthTexture_TexelSize.xy * half2(-1, -1) * _Rate;
                uv[1] = i.texcoord + _CameraDepthTexture_TexelSize.xy * half2(0, -1) * _Rate;
                uv[2] = i.texcoord + _CameraDepthTexture_TexelSize.xy * half2(1, -1) * _Rate;
                uv[3] = i.texcoord + _CameraDepthTexture_TexelSize.xy * half2(-1, 0) * _Rate;
                uv[4] = i.texcoord + _CameraDepthTexture_TexelSize.xy * half2(0, 0) * _Rate;
                uv[5] = i.texcoord + _CameraDepthTexture_TexelSize.xy * half2(1, 0) * _Rate;
                uv[6] = i.texcoord + _CameraDepthTexture_TexelSize.xy * half2(-1, 1) * _Rate;
                uv[7] = i.texcoord + _CameraDepthTexture_TexelSize.xy * half2(0, 1) * _Rate;
                uv[8] = i.texcoord + _CameraDepthTexture_TexelSize.xy * half2(1, 1) * _Rate;

                const half Gx[9] = {
                    -1,  0,  1,
                    -2,  0,  2,
                    -1,  0,  1
                };

                const half Gy[9] = {
                    -1, -2, -1,
                    0,  0,  0,
                    1,  2,  1
                };

                float edgeY = 0;
                float edgeX = 0;    
                float luminance = 0;

                float4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv[4]);
                float mask = 1;

                float maskNormal = SAMPLE_TEXTURE2D(_OutlineMask, sampler_LinearClamp, i.texcoord);
                
                if (maskNormal>0)
                {
                    return color;
                }

                for (int i = 0; i < 9; i++)
                {
                    mask *= SAMPLE_TEXTURE2D(_OutlineMask, sampler_LinearClamp, uv[i]);
                }
                
                for (int i = 0; i < 9; i++) {
                    float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uv[i]);
                    luminance = LinearEyeDepth(depth, _ZBufferParams) * 0.1;
                    edgeX += luminance * Gx[i];
                    edgeY += luminance * Gy[i];
                }

                float edge = (1 - abs(edgeX) - abs(edgeY));
                edge = saturate(edge);
                
                return lerp(_OutlineColor, color, edge);
                
            }
            
            ENDHLSL
        }
        
        
    }
}