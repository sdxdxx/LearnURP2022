Shader "URP/Cartoon/SimpleCartoon_Fixed"
{
    Properties
    {
        [Header(Tint)]
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        
        _MainTex("MainTex",2D) = "white"{}
        
        [Header(MatCap)]
        _MatCap("Mat Cap",2D) = "white"{}
        _MatCapLerp("MatCapLerp",Range(0,1)) = 0
        
         [Header(Diffuse)]
        _SmoothValue("Smooth Value",Range(0,0.1)) = 0
        
        [Header(Outline)]
        _OutlineColor("Outline Color",Color) = (0.0,0.0,0.0,0.0)
        _OutlineWidth("Outline Width",Range(0,5)) = 0
        
        [Header(NormalLine)]
    	[Toggle(_EnableNormalInline)] _EnableNormalInline("Enable Normal Inline",float) = 0
        _NormalInlineColor("Normal Inline Color",Color) = (1.0,1.0,1.0,1.0)
    	[Toggle(_EnableNormalOutline)] _EnableNormalOutline("Enable Normal Outline",float) = 0
        _NormalOutlineColor("Normal Outline Color",Color) = (1.0,1.0,1.0,1.0)
    }
    
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }
         
         HLSLINCLUDE
         #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
         CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float _SmoothValue;
            float _MatCapLerp;
            float4 _MainTex_ST;

            half4 _NormalInlineColor;
            half4 _NormalOutlineColor;
            //----------变量声明结束-----------
            CBUFFER_END

         TEXTURE2D(_CameraDepthTexture);
		 SAMPLER(sampler_CameraDepthTexture);
         TEXTURE2D(_NormalLineTexture);
         SAMPLER(sampler_NormalLineTexture);
         ENDHLSL
        
         
        
         pass
        {
            Tags { "LightMode" = "UniversalForward" }
            Cull Back
            
            ZWrite On
            
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature _EnableNormalInline
            #pragma shader_feature _EnableNormalOutline
            
            // 主光源和阴影
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT

            // 多光源和阴影
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS

            //开启光照贴图
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON

            #pragma multi_compile_fog
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);//定义贴图
            SAMPLER(sampler_MainTex);//定义采样器
            TEXTURE2D(_MatCap);
            SAMPLER(sampler_MatCap);
            //----------贴图声明结束-----------

            float3 SampleIndirectLightMap(float3 normalWS, float2 uvLM)
            {
	            #ifdef LIGHTMAP_ON
	                return SampleLightmap(uvLM, normalWS);//注意：这里默认没有采样存储了光线方向的光照贴图
	            #else
	                return SampleSH(normalWS);
	            #endif
	        }
            

            //Remap
            float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
             {
               return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
             }
            

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
                float3 nDirWS : TEXCOORD1;
                float3 posWS : TEXCOORD2;
                float4 screenPos : TEXCOORD3;
                float fogCoord : TEXCOORD4;
                float2 lightmapUV : TEXCOORD5;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                float4 posCS = TransformObjectToHClip(v.vertex.xyz);
                o.pos = posCS;
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv*_MainTex_ST.xy+_MainTex_ST.zw;
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                o.posWS = positionWS;
                o.screenPos = ComputeScreenPos(posCS);
                o.fogCoord = ComputeFogFactor(posCS.z);
                //光照贴图 UV
            	o.lightmapUV = v.lightmapUV* unity_LightmapST.xy + unity_LightmapST.zw;
                return o;
            }

            float3 CalculateDiffuseLightResult(float3 nDir, float3 lDir, float3 lightColor, float shadow)
            {
                float nDotl = dot(nDir,lDir);
                float lambert = max(0,nDotl);
                float halfLambert = nDotl*0.5+0.5;
                half3 result = halfLambert*shadow*lightColor;
                return result;
            }
            
            half4 frag (vertexOutput i) : SV_TARGET
            {
                float2 screenPos = i.screenPos.xy/i.screenPos.w;
                float4 shadowCoord = TransformWorldToShadowCoord(i.posWS);
                Light mainLight = GetMainLight(shadowCoord);
                float3 nDir= NormalizeNormalPerPixel(i.nDirWS);
                float3 lDir = mainLight.direction;
                float3 vDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
                float3 hDir = normalize(lDir+vDir);

                float3 nDirVS = TransformWorldToViewDir(nDir);
                half3 matcap = SAMPLE_TEXTURE2D(_MatCap,sampler_MatCap,abs(nDirVS.xy*0.5+0.5)).rgb;

                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv*_MainTex_ST.xy+_MainTex_ST.zw);
                half4 albedo = _BaseColor*mainTex;
                
                half3 bakedGI = SampleIndirectLightMap(nDir,i.lightmapUV);
                
                float mainLightRadiance = mainLight.distanceAttenuation;
                float mainDiffuse = CalculateDiffuseLightResult(nDir,lDir,mainLightRadiance,mainLight.shadowAttenuation);

                uint lightCount = GetAdditionalLightsCount();
            	float3 additionalDiffuse = half3(0,0,0);
				for (uint lightIndex = 0; lightIndex < lightCount; lightIndex++)
				{
				    Light additionalLight = GetAdditionalLight(lightIndex, i.posWS, 1);
					half3 additionalLightColor = additionalLight.color;
					float3 additionalLightDir = additionalLight.direction;
					// 光照衰减和阴影系数
                    float additionalLightRadiance =  additionalLight.distanceAttenuation;
					float3 perDiffuse = CalculateDiffuseLightResult(nDir,additionalLightDir,additionalLightColor*additionalLightRadiance,additionalLight.shadowAttenuation);
				    additionalDiffuse += perDiffuse;
				}

                float diffuse = mainDiffuse;
                float mask1 = 1-smoothstep(0.2-_SmoothValue,0.2,diffuse);
                float mask2 = 1-smoothstep(0.41-_SmoothValue,0.41,diffuse);
                float mask3 = 1-smoothstep(0.624-_SmoothValue,0.624,diffuse);
                float mask4 = 1-smoothstep(0.823-_SmoothValue,0.823,diffuse);
                float mask5 = 1-smoothstep(0.965-_SmoothValue,0.965,diffuse);
                float mask6 = 1 - mask5;
                mask2 = mask2 -mask1;
                mask3 = mask3 -mask2-mask1;
                mask4 = mask4 -mask3 - mask2 -mask1;
                mask5 = mask5 - mask4 -mask3 - mask2 -mask1;
                
                half3 diffuseColor1 = _BaseColor*albedo*mask1*half3(0.2829f,0.2976f,0.3584f);
                half3 diffuseColor2 = _BaseColor*albedo*mask2*half3(0.4024f,0.4244f,0.4811f);
                half3 diffuseColor3 = _BaseColor*albedo*mask3*half3(0.4396f,0.4660f,0.5377f);
                half3 diffuseColor4 = _BaseColor*albedo*mask4*half3(0.6031f,0.6451f,0.7641f);
                half3 diffuseColor5 = _BaseColor*albedo*mask5*half3(0.6776f,0.7272f,0.8584f);
                half3 diffuseColor6 = _BaseColor*albedo*mask6;
                half3 diffuse_main = diffuseColor1+diffuseColor2+diffuseColor3+diffuseColor4+diffuseColor5+diffuseColor6;
                half3 Diffuse = diffuse_main*mainLight.color+_BaseColor*half3(0.4024f,0.4244f,0.4811f)*additionalDiffuse;
                
                half3 FinalRGB = lerp(1,matcap,_MatCapLerp)*Diffuse+Diffuse*bakedGI;//Matcap+Diffuse

                //Fog
                FinalRGB = MixFog(FinalRGB, i.fogCoord);

                //NormalLine
                float3 normalLine = SAMPLE_TEXTURE2D(_NormalLineTexture,sampler_NormalLineTexture,screenPos);
                half3 normalInline = normalLine.r * _NormalInlineColor.rgb*_NormalInlineColor.a;
                half3 normalOutline = normalLine.b * _NormalOutlineColor.rgb*_NormalOutlineColor.a;

                #ifdef _EnableNormalInline
                    FinalRGB+= normalInline;
                #endif
                
                #ifdef _EnableNormalOutline
                    FinalRGB += normalOutline;
                #endif
                
                return half4(FinalRGB,1.0);
            }
            
            ENDHLSL
        }

        //Outline
        pass
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            
            ZWrite On
            Cull Front
            
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            //----------贴图声明开始-----------
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _OutlineColor;
            float _OutlineWidth;
            //----------变量声明结束-----------
            CBUFFER_END

            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float3 color : COLOR;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float3 nDirWS : TEXCOORD1;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz+v.normal* _OutlineWidth * 0.1);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                return _OutlineColor;
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
            float4 _BaseMap_ST;
            // -------------------------------------
            // Includes
            //#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UniversalMetaPass.hlsl"
            half4 UniversalFragmentMetaLit(Varyings input) : SV_Target
			{
			    MetaInput metaInput;
			    metaInput.Albedo = _BaseColor;
			    metaInput.Emission = 0;
			    return UniversalFragmentMeta(input, metaInput);
			}

            ENDHLSL
        }

        //解决深度引动模式Depth Priming Mode问题
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/DepthNormals"
        UsePass "Universal Render Pipeline/Lit/SHADOWCASTER"
    }
}