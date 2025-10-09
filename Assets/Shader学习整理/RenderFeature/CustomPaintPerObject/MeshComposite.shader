// Hidden_Painter_MeshComposite.shader  修正版
Shader "Hidden/Painter/MeshComposite"
{
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }
        Cull Off
        ZWrite On
        ZTest LEqual
        Blend SrcAlpha OneMinusSrcAlpha
        
        Pass
        {
            Name "MeshComposite"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

             #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        // ^ 提供 GetNormalizedScreenSpaceUV

        TEXTURE2D(_SourceTex);
        SAMPLER(sampler_SourceTex);

        struct Attributes
        {
            float3 posOS : POSITION;
        };
        
        struct Varings
        {
            float4 posCS : SV_POSITION;
        };

        Varings vert (Attributes v)
        {
            Varings o;
            o.posCS = TransformObjectToHClip(v.posOS); // 当前相机同一套VP矩阵
            return o;
        }

        float4 frag (Varings i) : SV_Target
        {
            // ✅ 正确的屏幕UV（含 RTHandle 缩放与平台翻转）
            float2 uv = GetNormalizedScreenSpaceUV(i.posCS);
            return SAMPLE_TEXTURE2D(_SourceTex, sampler_SourceTex, uv);
        }
            ENDHLSL
        }
    }
    Fallback Off
}
