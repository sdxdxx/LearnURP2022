Shader "URP/PostProcessing/Skin"
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
        
        //SkinMask
        pass
        {
            Tags{"LightMode"="UniversalForward"}
            
            Name "SkinMask"
             
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float _BlurSize;
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
        
        //Gaussian
        pass
        {
            Name "Gaussian"
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag_Gaussian

           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
           #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            #include  "SkinMaskBlit.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_SkinMask);//获取到摄像机渲染画面的Texture
            SAMPLER(sampler_SkinMask);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _SSSColor;
            float _BlurSize;
            float2 _offsets;
            float4 _MainTex_ST;
            //----------变量声明结束-----------
            CBUFFER_END
            
            half4 frag_Gaussian (Varyings i) : SV_TARGET
            {
                half4 albedo =  SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);
                float skinMask = SAMPLE_TEXTURE2D(_SkinMask,sampler_SkinMask,i.texcoord);
                
                 float2 uv = i.texcoord.xy;  
                
                //计算一个偏移值
                // offset（1，0，0，0）代表水平方向
                // offset（0，1，0，0）表示垂直方向  
                _offsets *= _BlitTexture_TexelSize.xyxy;  
                
                //由于uv可以存储4个值，所以一个uv保存两个vector坐标，_offsets.xyxy * float4(1,1,-1,-1)可能表示(0,1,0-1)，表示像素上下两个  
                //坐标，也可能是(1,0,-1,0)，表示像素左右两个像素点的坐标，下面*2.0，同理
                float4 uv01 = i.texcoord.xyxy + _offsets.xyxy * float4(1, 1, -1, -1);  
                float4 uv23 = i.texcoord.xyxy + _offsets.xyxy * float4(1, 1, -1, -1) * 2.0;  
                
                //中心像素值
                float3 sum = 0.4026 * SAMPLE_TEXTURE2D(_BlitTexture, sampler_PointClamp,uv).rgb;
                sum += 0.2442  * SAMPLE_TEXTURE2D(_BlitTexture, sampler_PointClamp,uv01.xy).rgb;
                sum += 0.2442  * SAMPLE_TEXTURE2D(_BlitTexture, sampler_PointClamp,uv01.zw).rgb;
                sum += 0.0545 * SAMPLE_TEXTURE2D(_BlitTexture, sampler_PointClamp,uv23.xy).rgb;
                sum += 0.0545 * SAMPLE_TEXTURE2D(_BlitTexture, sampler_PointClamp,uv23.zw).rgb;
                
                return float4(sum, 1.0);
                
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
            #include  "SkinMaskBlit.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_SkinMask);
            SAMPLER(sampler_SkinMask);
            TEXTURE2D(_GaussianSkinTex);
            SAMPLER(sampler_GaussianSkinTex);
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _SSSColor;
            float _BlurSize;
            float2 _offsets;
            float4 _MainTex_ST;
            float _SSSIntensity;
            //----------变量声明结束-----------
            CBUFFER_END
            
            half4 frag (Varyings i) : SV_TARGET
            {
                half4 albedo =  SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);
                float skinMask = SAMPLE_TEXTURE2D(_SkinMask,sampler_SkinMask,i.texcoord);
                half3 gaussianSkin = SAMPLE_TEXTURE2D(_GaussianSkinTex,sampler_GaussianSkinTex,i.texcoord);
                float rawDepthCenter = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_PointClamp, float2(0.5f,0.5f));
                float linearDepthCenter = LinearEyeDepth(rawDepthCenter ,_ZBufferParams);
                float rawDepth =  SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_PointClamp, i.texcoord);
                float linearDepth = LinearEyeDepth(rawDepth,_ZBufferParams);
            	float depth01 = Linear01Depth(rawDepth,_ZBufferParams);

                float depthMask = saturate(linearDepth-linearDepthCenter);
                

                float fac = 1-pow(saturate(max(max(albedo.r, albedo.g), albedo.b) * 1), 0.3);
                half3 FinalRGB = albedo.rgb +depthMask*gaussianSkin*skinMask*_SSSColor*fac*_SSSIntensity;
                
                return float4(FinalRGB,1.0);
                
            }
            
            ENDHLSL
        }
    }
}