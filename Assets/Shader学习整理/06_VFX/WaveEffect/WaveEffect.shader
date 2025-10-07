Shader "URP/VFX/WaveEffect"
{
    Properties
    {
        [HDR]_BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _MainMask("Main Mask",2D) = "white"{}
        _Noise("Noise",2D) = "black"{}
        _DistortionSmooth("Distortion Smooth",Range(0,1)) = 0.1
        _DistortionSpeed("Distortion Speed(XY)",Vector) = (0.0,0.0,0.0,0.0)
        _DistortionIntensity("Distortion Intensity",Range(0,1)) = 0
    }
    
    SubShader
    {
         Tags
        {
            "Queue" = "Transparent"
            "IgnoreProjector" = "true"
            "RenderType" = "Transparent"
            "PreviewType"="Plane"
            "RenderPipeline" = "UniversalPipeline"
        }
         HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_GrabColorTex);
            TEXTURE2D(_CameraOpaqueTexture);
            TEXTURE2D(_MainMask);//定义贴图
            SAMPLER(sampler_MainMask);//定义采样器
            TEXTURE2D(_Noise);//定义贴图
            SAMPLER(sampler_Noise);//定义采样器
            TEXTURE2D(_WaveEffectMask);//定义贴图
            
            //----------贴图声明结束-----------
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float4 _MainMask_ST;
            float4 _Noise_ST;
            float2 _DistortionSpeed;
            float _DistortionIntensity;
            float _DistortionSmooth;
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
                float4 posCS : TEXCOORD2;
                float3 posOS : TEXCOORD3;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                float4 posCS = TransformObjectToHClip(v.vertex.xyz);
                o.posCS = posCS;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                o.posOS = v.vertex;
                return o;
            }
            
            float GenerateSquareSmoothArea(float2 uv)
            {
                float edge1 = smoothstep(0,0.01,uv.x);
                float edge2 = smoothstep(0,_DistortionSmooth,uv.y);
                float edge3 = 1-smoothstep(1-_DistortionSmooth,1,uv.x);
                float edge4 = 1-smoothstep(1-_DistortionSmooth,1,uv.y);

                float result = min(edge1,edge2);
                result = min(result,edge3);
                result = min(result,edge4);
                return result;
            }
            

            float4 frag (vertexOutput i) : SV_TARGET
            {
                float4 screenPos = ComputeScreenPos(i.posCS);
                float2 realScreenPos = screenPos.xy/screenPos.w;

                float vertexDistance = distance(_WorldSpaceCameraPos.xyz,TransformObjectToWorld(i.posOS));
                float linearDistanceMask = 1-smoothstep(10,50,vertexDistance);

                
                float noise = SAMPLE_TEXTURE2D(_Noise,sampler_Noise,i.uv*_Noise_ST.xy+_Noise_ST.zw+_Time.x*float2(-_DistortionSpeed.x,0));
                float mainMask = SAMPLE_TEXTURE2D(_MainMask,sampler_MainMask,i.uv*_MainMask_ST.xy+_MainMask_ST.zw).r;
                float smoothMask = GenerateSquareSmoothArea(i.uv)*(1-i.uv.x);
                
                
                
                float distorationMask = smoothMask*linearDistanceMask;
                float2 waveEffectMaskUV = realScreenPos+noise*_DistortionIntensity*0.1*distorationMask;
                float waveEffectMask = SAMPLE_TEXTURE2D(_WaveEffectMask,sampler_LinearClamp,waveEffectMaskUV).r;
                float2 albedoUV = realScreenPos+noise*_DistortionIntensity*0.1*distorationMask*waveEffectMask;
                half3 albedo = SAMPLE_TEXTURE2D(_GrabColorTex,sampler_LinearClamp,albedoUV);
                float3 finalRGB = _BaseColor*albedo*mainMask;
                float4 result = float4(finalRGB*_BaseColor.rgb,1.0);
                return result;
            }
         ENDHLSL
         pass
        {
            Tags
            {
                "Name" = "Wave Effect"
                "LightMode" = "WaveEffect"
            }
            
            Lighting Off
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            ENDHLSL
        }

        pass
        {
            Tags
            {
                "Name" = "Wave Effect Mask"
                "LightMode" = "WaveEffectMask"
            }
            
            Lighting Off
            ZWrite Off
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag_Mask

            float4 frag_Mask (vertexOutput i) : SV_TARGET
            {
                return float4(1,0,0,1);
            }
            
            ENDHLSL
        }
         
    }
}