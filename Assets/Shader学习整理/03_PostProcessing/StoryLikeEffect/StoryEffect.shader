Shader "URP/PostProcessing/StoryEffect"
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
            TEXTURE2D(_CameraDepthTexture);
            TEXTURE2D(_MainTex);
            TEXTURE2D(_PaperEffectTex);
            TEXTURE2D(_PaperMaskTex);
            TEXTURE2D(_PaperMaskNoise);
            TEXTURE2D(_VignetteMask);
            
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            half4 _VignetteColor;
            half4 _PaperEffectTex_ST;
            half4 _PaperEffectTex_TexelSize;
            half4 _PaperMaskTex_TexelSize;
            half4 _PaperMaskNoise_TexelSize;
            half _PaperEffectIntensity;
            half _PaperMaskEdgeWidth;
            half _PaperMaskEdgeFlowSpeed;
            half _VignetteIntensity;
            half _TestValue;
            //----------变量声明结束-----------
            CBUFFER_END

            inline half LerpRGBA_Wrap4(half4 rgba, half t)
            {
                t = pow(frac(t),2.2);                // wrap 到 [0,1)
                half seg = t * 4.0h;        // 0..4
                half f   = frac(seg);       // 段内插值因子 0..1
                half idx = floor(seg);      // 段索引 0,1,2,3
                
                if (idx < 1.0h) return lerp(rgba.r, rgba.g, f); // r->g
				else if (idx < 2.0h) return lerp(rgba.g, rgba.b, f); // g->b
				else if (idx < 3.0h) return lerp(rgba.b, rgba.a, f); // b->a
				else return lerp(rgba.a, rgba.r, f); // a->r
            }

            inline float GetAspectFromScreen()
			{
			    float2 sz = _ScreenParams.xy;
			    return sz.x / max(sz.y, 1.0);
			}
            
            half4 frag (Varyings i) : SV_TARGET
            {
            	float aspectRatio = GetAspectFromScreen();

            	half3 cameraFrontDirWS = normalize(TransformViewToWorldDir(float3(0,0,-1)));
            	half3 cameraToWorldOriginDir = normalize(_WorldSpaceCameraPos);
            	half3 cosSita = dot(cameraFrontDirWS,cameraToWorldOriginDir);
            	half cameraDistanceToWorldXZPlane = distance(_WorldSpaceCameraPos,float3(0,0,0))*cosSita;
            	half3 worldOriginPosVS = TransformWorldToView(float3(0,0,0));
                half4 albedo =  SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);
            	
            	float2 paperEffectUV = (i.texcoord+worldOriginPosVS.xy/cameraDistanceToWorldXZPlane)*_PaperEffectTex_ST.xy*float2(9*aspectRatio,9)+_PaperEffectTex_ST.zw;
                half4 paperEffect = SAMPLE_TEXTURE2D(_PaperEffectTex, sampler_LinearRepeat,paperEffectUV);
                half realPaperEffect = LerpRGBA_Wrap4(paperEffect,_Time.x);
            	realPaperEffect = lerp(1,pow(realPaperEffect,max(1,_PaperEffectIntensity)),_PaperEffectIntensity);
            	float2 paperMaskUV = (i.texcoord.xy+float2(worldOriginPosVS.x/cameraDistanceToWorldXZPlane,0))*float2(22*aspectRatio,1)*float2(0.5,1);
            	float2 paperMaskNoiseUV = (i.texcoord.xy+float2(worldOriginPosVS.x/cameraDistanceToWorldXZPlane,0))*_ScreenParams.xy*_PaperMaskNoise_TexelSize.xy*float2(0.2,1);
                half paperMask = SAMPLE_TEXTURE2D(_PaperMaskTex,sampler_LinearRepeat,paperMaskUV).r;
            	paperMask = smoothstep(0,_PaperMaskEdgeWidth,paperMask);
            	half paperMaskNoise = SAMPLE_TEXTURE2D(_PaperMaskNoise,sampler_LinearRepeat,paperMaskNoiseUV+_Time.x*_PaperMaskEdgeFlowSpeed*0.1*5).r;
	            half realPaperMask = smoothstep(paperMaskNoise*paperMask,paperMaskNoise,paperMask);
            	realPaperMask = lerp(paperMask,1,realPaperMask);

            	half vignetteMask = SAMPLE_TEXTURE2D(_VignetteMask,sampler_LinearRepeat,i.texcoord).r;
            	vignetteMask = smoothstep(0,_VignetteIntensity,vignetteMask);
            	half4 vignette = lerp(_VignetteColor,1,vignetteMask);
            	half4 result = realPaperMask*_BaseColor*realPaperEffect*albedo*vignette;
            	result = lerp(result*vignette,result,vignetteMask);
            	return result;
            }
            
            ENDHLSL
        }
    }
}