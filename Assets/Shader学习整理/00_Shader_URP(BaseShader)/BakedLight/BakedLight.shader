Shader "URP/BakedLight"
{
    Properties
    {
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
    	[Toggle(_EMISSION)]_EMISSION("Enable Emission",float) = 0.0
    	[HDR]_EmissionColor("Emission Color",Color) = (0.0,0.0,0.0,1.0)
        _BaseMap("Base Map",2D) = "white"{}
    }
    
    SubShader
    {
         Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }
    	
    	//解决深度引动模式Depth Priming Mode问题
        UsePass "Universal Render Pipeline/Unlit/DepthOnly"
        UsePass "Universal Render Pipeline/Unlit/DepthNormalsOnly"

         pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile  _MAIN_LIGHT_SHADOWS
			#pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile  _SHADOWS_SOFT

            //开启光照贴图
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON

            #pragma shader_feature_local_fragment _EMISSION
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_BaseMap);//定义贴图
            SAMPLER(sampler_BaseMap);//定义采样器
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float4 _BaseMap_ST;
            half4 _EmissionColor;
            //----------变量声明结束-----------
            CBUFFER_END

            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            	float2 lightmapUV : TEXCOORD1;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 posWS : TEXCOORD2;
            	float2 lightmapUV : TEXCOORD3;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.normal = v.normal;
                o.uv = v.uv*_BaseMap_ST.xy+_BaseMap_ST.zw;
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                o.posWS = positionWS;
            	//光照贴图 UV
            	o.lightmapUV = v.lightmapUV* unity_LightmapST.xy + unity_LightmapST.zw;
                return o;
            }

            float3 SampleIndirectLightMap(float3 normalWS, float2 uvLM)
            {
	            #ifdef LIGHTMAP_ON
	                return SampleLightmap(uvLM, normalWS);//注意：这里默认没有采样存储了光线方向的光照贴图
	            #else
	                return SampleSH(normalWS);
	            #endif
	        }

            half4 frag (vertexOutput i) : SV_TARGET
            {
            	float3 nDirWS = TransformWorldToObjectNormal(i.normal);
            	half3 bakedGI = SampleIndirectLightMap(nDirWS,i.lightmapUV);
            	float4 shadowCoord = TransformWorldToShadowCoord(i.posWS);
                float shadow = MainLightRealtimeShadow(shadowCoord);
                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv);
            	half4 emission = 0;
            	#ifdef _EMISSION
            	emission = _EmissionColor;
            	#endif
            	
            	half3 finalRGB = albedo.rgb*_BaseColor.rgb*bakedGI*shadow+emission;
                return float4(finalRGB,1.0);
            }
            ENDHLSL
        }

        //阴影Pass
        Pass
		{
		Name "ShadowCaster"
		Tags{ "LightMode" = "ShadowCaster" }

		ZWrite On
		ZTest LEqual

		HLSLPROGRAM

		 #pragma vertex vert
		#pragma fragment frag

		#define SHADERPASS_SHADOWCASTER

		#pragma shader_feature_local _ DISTANCE_DETAIL
		#pragma require geometry
		#pragma require tessellation tessHW

		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

		#pragma target 4.6

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
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

		half4 frag(vertexOutput input) : SV_TARGET
		{
			return 1;
		 }

		ENDHLSL
		}

		//MetaPass
		// This pass it not used during regular rendering, only for lightmap baking.
        Pass
        {
            Name "Meta"
            Tags
            {
                "LightMode" = "Meta"
            }

            // -------------------------------------
            // Render State Commands
            Cull Off

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMetaLit
            
            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UniversalMetaPass.hlsl"
            half4 UniversalFragmentMetaLit(Varyings input) : SV_Target
			{
			    MetaInput metaInput;
			    metaInput.Albedo = _BaseColor;
			    metaInput.Emission = _EmissionColor;
			    return UniversalFragmentMeta(input, metaInput);
			}

            ENDHLSL
        }
    }
}