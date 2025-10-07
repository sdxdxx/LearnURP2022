Shader "URP/3DSample"
{
    Properties
    {
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _NoiseTex("3D Noise Tex",3D) = "white"{}
        _NosieTexScale("Nosie Tex Scale",float) = 1
        _NoiseTexOffset("XYZ: 3D Noise Tex Offset",Vector) = (0,0,0,0)
    }
    
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "Queue"="Geometry"
            "RenderPipeline" = "UniversalPipeline"
        }

        //解决深度引动模式Depth Priming Mode问题
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/DepthNormals"
        
        pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_CameraOpaqueTexture);//获取到摄像机渲染画面的Texture
            SAMPLER(sampler_CameraOpaqueTexture);
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            TEXTURE3D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            float _NosieTexScale;
            float3 _NoiseTexOffset;
            half4 _BaseColor;
            //----------变量声明结束-----------
            CBUFFER_END
            

            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 nDirWS : TEXCOORD1;
                float4 screenPos : TEXCOORD2;
                float3 posOS : TEXCOORD3;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                float4 posCS = TransformObjectToHClip(v.vertex.xyz);
                o.pos = posCS;
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                o.screenPos = ComputeScreenPos(posCS);
                o.posOS= v.vertex.xyz;
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                
                return SAMPLE_TEXTURE3D(_NoiseTex,sampler_NoiseTex,TransformObjectToWorld(i.posOS)*_NosieTexScale+_NoiseTexOffset).r*_BaseColor;
            }
            
            ENDHLSL
        }
    }
}