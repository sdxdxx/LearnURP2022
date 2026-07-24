Shader "URP/DepthRim"
{
    Properties
    {
        _DepthRimWidth("Depth Rim Width",Float) = 0.0
        _DepthRimMinRange("Depth Rim Min Range",Range(0.0,1.0)) = 0.0
        _DepthRimMaxRange("Depth Rim Max Range",Range(0.0,1.0)) = 1.0
        [HDR]_DepthRimColor("Depth Rim Color",Color) = (1.0,1.0,1.0,1.0)
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/DepthNormals"

        pass
        {
            Name "ForwardUnlit"

            Tags
            {
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            CBUFFER_START(UnityPerMaterial)
            float _DepthRimWidth;
            float _DepthRimMinRange;
            float _DepthRimMaxRange;
            half4 _DepthRimColor;
            CBUFFER_END

            struct VertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct VertexOutput
            {
                float4 pos : SV_POSITION;
                float4 screenPos : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
            };

            VertexOutput vert (VertexInput v)
            {
                VertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.screenPos = ComputeScreenPos(o.pos);
                o.normalWS = TransformObjectToWorldNormal(v.normal);
                return o;
            }

            half4 frag (VertexOutput i) : SV_TARGET
            {
                float3 normalWS = normalize(i.normalWS);
                float3 normalVS = TransformWorldToViewDir(normalWS);
                float2 screenUV = i.screenPos.xy/i.screenPos.w;
                float2 offsetUV = screenUV+normalVS.xy*_DepthRimWidth*0.001;

                float depthTexSample_Offset = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,offsetUV);
                float depthTexSample = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,screenUV);
                float offsetDepth = LinearEyeDepth(depthTexSample_Offset,_ZBufferParams);
                float depth = LinearEyeDepth(depthTexSample,_ZBufferParams);

                float rim = saturate(offsetDepth-depth);
                rim = smoothstep(min(_DepthRimMinRange,0.99),_DepthRimMaxRange,rim);

                half4 color = half4(rim*_DepthRimColor.rgb,1.0);
                return color;
            }

            ENDHLSL
        }
    }
}
