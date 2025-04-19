Shader "URP/PostProcessing/ColorTint"
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
            SAMPLER(sampler_CameraOpaqueTexture);
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            //float4 _CameraOpaqueTexture_ST;
            float4 _MainTex_ST;
            //----------变量声明结束-----------
            CBUFFER_END
            
            half4 frag (Varyings i) : SV_TARGET
            {
                half4 albedo =  SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);
                return albedo*_BaseColor;
            }
            
            ENDHLSL
        }
    }
}