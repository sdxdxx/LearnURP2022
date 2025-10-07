Shader "URP/SSS/Jade"
{
    Properties
    {
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _AddColor("Add Color",Color) = (1.0,1.0,1.0,1.0)
        _ThicknessTex("Thickness Tex",2D) = "white"{}
        
        [Header(Scattering)]
    	_ScatteringDistoration("Scattering Distoration",float) = 1
    	_ScatteringPow("Scattering Power",Range(0,50)) = 1
    	_ScatteringInt("Scattering Intensity",Range(0,5)) = 1
        _CubeMap("Cube Map",Cube) = "white"{}
    }
    
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
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
            // 主光源和阴影
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT

            // 多光源和阴影
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_ThicknessTex);//定义贴图
            SAMPLER(sampler_ThicknessTex);//定义采样器
            TEXTURECUBE(_CubeMap);
            SAMPLER(sampler_CubeMap);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            half4 _AddColor;
            float4 _ThicknessTex_ST;

            float _ScatteringDistoration;
            float _ScatteringPow;
            float _ScatteringInt;

            float4 _CubeMap_HDR;
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
                float3 posWS : TEXCOORD2;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv*_ThicknessTex_ST.xy+_ThicknessTex_ST.zw;
                o.posWS = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                
                float thickness = 1.0-SAMPLE_TEXTURE2D(_ThicknessTex,sampler_ThicknessTex,i.uv).r;
                float3 nDir = i.nDirWS;
                float3 lDir = _MainLightPosition.xyz;
                float3 vDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
                float nDotl = dot(nDir,lDir);

                //Diffuse
                float lambert = saturate(nDotl);
                half3 diffuse = lambert*_BaseColor+_AddColor;

                float4 shadowCoord = TransformWorldToShadowCoord(i.posWS);
                Light mainLight = GetMainLight(shadowCoord);

                 //scattering
            	float3 hDir2 = normalize(-lDir+(nDir*0.5+0.5)*_ScatteringDistoration);
            	half scattering = pow(max(0,dot(vDir,hDir2)),_ScatteringPow)*_ScatteringInt;
                
                //获取灯光组
                uint pixelLightCount = GetAdditionalLightsCount();
                //逐个获取灯光
                for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
                {
                    //获取当前灯光数据
                    Light addlight = GetAdditionalLight(lightIndex, i.posWS);
                    
                    float3 addLightDir = addlight.direction;
                    float3 addHalfDir2 = normalize(-addLightDir+(nDir*0.5+0.5)*_ScatteringDistoration);
                    scattering+=pow(max(0,dot(vDir,addHalfDir2)),_ScatteringPow)*_ScatteringInt;
                }

                scattering*=thickness;

                //光泽反射
                float3 reflect_dir = reflect(-vDir,nDir);
                float4 hdr = SAMPLE_TEXTURECUBE(_CubeMap,sampler_CubeMap,reflect_dir);
                half3 envColor = DecodeHDREnvironment(hdr,_CubeMap_HDR);
                float fresnel = 1.0 -max(0.0, dot(nDir,vDir));
                half3 final_envColor = envColor*fresnel; 
                
                half3 finalRGB = scattering*_BaseColor+final_envColor+diffuse;

                half4 result = half4(finalRGB,1.0);
                
                return result;
            }
            
            ENDHLSL
        }
    }
}