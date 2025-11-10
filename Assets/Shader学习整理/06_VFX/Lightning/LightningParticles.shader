Shader "URP/VFX/LightningParticles"
{
    Properties
    {
        [Toggle(_EnableMultiLightning)]_EnableMultiLightning("Enable Multi Lightning",float) = 0.0
        [HDR]_TintColor ("Tint Color", Color) = (0.5,0.5,0.5,0.5)
        _MainTex ("Particle Texture", 2D) = "white" {}
        _Gradient("Gradient Texture", 2D) = "white" {}
        _Stretch("Stretch", Range(-2,2)) = 1.0
        _Offset("Offset", Range(-2,2)) = 1.0
        _Speed("Speed", Range(-2,2)) = 1.0
    }
    
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
        }
         
        pass
        {
            Blend One OneMinusSrcAlpha
            ColorMask RGB
            Cull Off
            Lighting Off
            ZWrite Off
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature _EnableMultiLightning
            
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_Gradient);
            SAMPLER(sampler_Gradient);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _TintColor;
            float _Stretch, _Offset;
            float _Speed;

            float4 _MainTex_ST;
            float4 _Gradient_ST;
            //----------变量声明结束-----------
            CBUFFER_END
            
            struct vertexInput
            {
                float4 vertex : POSITION;
                half4 color : COLOR;
                float4 texcoord : TEXCOORD0;
                float4 texcoord1 : TEXCOORD1;
            };

            struct vertexOutput
            {
                float4 vertex : SV_POSITION;
                half4 color : COLOR;
                float4 texcoord : TEXCOORD0;
                float4 texcoord1 : TEXCOORD1;
                float2 texcoord2 : TEXCOORD3;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.vertex = TransformObjectToHClip(v.vertex);
          
                o.color = v.color;
                o.texcoord.xy = TRANSFORM_TEX(v.texcoord,_MainTex);
                o.texcoord2 = TRANSFORM_TEX(v.texcoord,_Gradient);
 
                // Custom Data from particle system
                o.texcoord.z = v.texcoord.z;
                o.texcoord.w = v.texcoord.w;
                o.texcoord1 = v.texcoord1;
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                // Custom Data from particle system  
                float lifetime = i.texcoord.z+0.001;
                float randomOffset = i.texcoord.w;
                float randomOffset2 = i.texcoord1.x;
     
                //fade the edges
                float gradientfalloff =  smoothstep(0.99, 0.95, i.texcoord2.x) * smoothstep(0.99,0.95,1- i.texcoord2.x);
                // moving UVS
                float2 movingUV = float2(i.texcoord.x +randomOffset + (_Time.x * _Speed) ,i.texcoord.y);
                half4 tex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,movingUV)* gradientfalloff;
     
                //cutoff for alpha
                float cutoff = step(lifetime, tex);

                

                float2 uv = float2(0,0);
                // stretched uv for gradient map
                # ifdef _EnableMultiLightning
                    float idx = floor(randomOffset2*4);
                    float realLightning = tex.a;
                    if (idx<1)
                    {
                        realLightning = tex.r;
                    }
                    else if(idx<2)
                    {
                        realLightning = tex.g;
                    }
                    else if(idx<3)
                    {
                        realLightning = tex.b;
                    }
                    uv = float2((realLightning * _Stretch)- lifetime + _Offset, 1);
                #else
                    uv = float2((tex.r * _Stretch)- lifetime + _Offset, 1) ;
                #endif
                float4 colorMap = SAMPLE_TEXTURE2D(_Gradient,sampler_Gradient,uv);
                // everything together
                half4 col;       
                col.rgb = colorMap.rgb * _TintColor * i.color.rgb;
                col.a = cutoff;
                col *= col.a;
                return col;
            }
            
            ENDHLSL
        }
    }
}