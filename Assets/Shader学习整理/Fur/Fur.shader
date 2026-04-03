Shader "URP/Fur"
{
    Properties
    {
        [Header(Main Layer)]
        _MainTex("Main Texture", 2D) = "white" {}

        [Header(PBR)]
        _ColorTint("Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
        _MetallicSmoothnessTex("Metallic Smoothness Texture", 2D) = "white" {}
        _Smoothness("Smoothness", Range(0, 1)) = 0
        _Metallic("Metallic", Range(0, 1)) = 0

        [Header(Normal)]
        _NormalMap("Normal Map", 2D) = "bump" {}
        _NormalInt("Normal Intensity", Range(0, 5)) = 1
        _Test("Test", Range(0, 1)) = 0

        [Header(Fur)]
        _FurNoise("Fur Noise", 2D) = "black" {}
        _FurColor("Fur Color", Color) = (1.0, 0.0, 0.0, 1.0)
        _FurLength("Fur Length", Range(0, 1)) = 0.5
        _GravityStrength("Gravity Strength", Range(0, 1)) = 0.5
        [Toggle(_USE_FUR_BXDF)] _UseFurBxDF("Use Fur BxDF", Float) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
            "RenderPipeline" = "UniversalPipeline"
        }
        
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/DepthNormals"

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

        #pragma multi_compile _MAIN_LIGHT_SHADOWS
        #pragma multi_compile _MAIN_LIGHT_SHADOWS_CASCADE
        #pragma multi_compile _SHADOWS_SOFT
        
        #pragma shader_feature _ _USE_FUR_BXDF

        #define kDielectricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04)

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        TEXTURE2D(_CameraDepthTexture);
        SAMPLER(sampler_CameraDepthTexture);

        TEXTURE2D(_NormalMap);
        SAMPLER(sampler_NormalMap);

        TEXTURE2D(_MetallicSmoothnessTex);
        SAMPLER(sampler_MetallicSmoothnessTex);

        TEXTURE2D(_FurNoise);
        SAMPLER(sampler_FurNoise);

        CBUFFER_START(UnityPerMaterial)
            half4 _ColorTint;

            float _NormalInt;
            float4 _NormalMap_ST;

            float _Smoothness;
            float _Metallic;

            half4 _RimCol;
            float _RimWidth;

            float4 _MainTex_ST;

            half4 _FurColor;
            float4 _FurNoise_ST;

            float _FurLength;
        
            float _GravityStrength;
        CBUFFER_END

        int _LoopIndex;
        int _LoopTimes;

        float D_GGX_Custom(float NoH, float roughness)
        {
            float remappedSquareRoughness = pow(lerp(0.002, 1.0, roughness), 2.0);
            float denominator = pow(NoH * NoH * (remappedSquareRoughness - 1.0) + 1.0, 2.0) * PI;
            return remappedSquareRoughness / max(denominator, 0.000001);
        }

        float G_Smith_Custom(float NoL, float NoV, float roughness)
        {
            float directLightK = pow(roughness + 1.0, 2.0) / 8.0;
            float indirectLightK = pow(roughness, 2.0) / 2.0;

            float geometryLeft = NoL / lerp(NoL, 1.0, directLightK);
            float geometryRight = NoV / lerp(NoV, 1.0, indirectLightK);

            return geometryLeft * geometryRight;
        }

        float3 FresnelSchlick(float cosTheta, float3 F0)
        {
            return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
        }

        float3 FresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
        {
            return F0 + (max(float3(1.0, 1.0, 1.0) * (1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
        }

        float3 FresnelLerp(half3 F0, half3 F90, half cosA)
        {
            half t = Pow4(1.0 - cosA);
            return lerp(F0, F90, t);
        }

        float3 CalculateIBLResult(
            float3 normalWS,
            float3 viewDirectionWS,
            half3 albedo,
            float3 F0,
            float3 specularResult,
            float smoothness,
            float roughness,
            float perceptualRoughness,
            float metallic,
            float NoV)
        {
            half3 ambientContrib = SampleSH(normalWS);
            float3 ambient = 0.03 * albedo;

            float3 iblDiffuse = max(half3(0, 0, 0), ambient.rgb + ambientContrib);
            float3 finalFresnel = FresnelSchlickRoughness(max(NoV, 0.0), F0, roughness);
            float3 kdLast = (1.0 - finalFresnel) * (1.0 - metallic);

            float mipRoughness = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);
            float3 reflectVector = reflect(-viewDirectionWS, normalWS);

            half mip = mipRoughness * UNITY_SPECCUBE_LOD_STEPS;
            half4 rgbm = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectVector, mip);

            float3 iblSpecular = DecodeHDREnvironment(rgbm, unity_SpecCube0_HDR);

            float surfaceReduction = 1.0 / (roughness * roughness + 1.0);

            float oneMinusReflectivity = 1.0 - max(max(specularResult.r, specularResult.g), specularResult.b);
            oneMinusReflectivity = oneMinusReflectivity * (1.0 - metallic);

            float grazingTerm = saturate(smoothness + (1.0 - oneMinusReflectivity));

            float3 indirectResult =
                iblDiffuse * kdLast * albedo +
                iblSpecular * surfaceReduction * FresnelLerp(F0, grazingTerm, NoV);

            return indirectResult;
        }

        float3 UnpackScaleNormalCustom(float4 packedNormal, float bumpScale)
        {
            float3 normalTS = UnpackNormal(packedNormal);
            normalTS.xy *= bumpScale;
            normalTS.z = sqrt(1.0 - saturate(dot(normalTS.xy, normalTS.xy)));
            return normalTS;
        }

        struct VertexInput
        {
            float4 positionOS : POSITION;
            float3 normalOS : NORMAL;
            float4 tangentOS : TANGENT;
            float4 color : COLOR;
            float2 uv : TEXCOORD0;
        };

        struct VertexOutput
        {
            float4 positionCS : SV_POSITION;
            float2 uv : TEXCOORD0;
            float3 normalWS : TEXCOORD1;
            float3 positionWS : TEXCOORD2;
            float4 screenPosition : TEXCOORD3;
            float3 tangentWS : TEXCOORD4;
            float3 bitangentWS : TEXCOORD5;
            float4 color : TEXCOORD6;
        };

        struct VertexInputFur
        {
            float4 positionOS : POSITION;
            float3 normalOS : NORMAL;
            float2 uv : TEXCOORD0;
        };

        struct VertexOutputFur
        {
            float4 positionCS : SV_POSITION;
            float2 uv : TEXCOORD0;
            float3 normalWS : TEXCOORD1;
            float3 positionWS : TEXCOORD2;
        };

        VertexOutput Vert(VertexInput v)
        {
            VertexOutput o;
            float4 positionCS = TransformObjectToHClip(v.positionOS.xyz);

            o.positionCS = positionCS;
            o.normalWS = TransformObjectToWorldNormal(v.normalOS);
            o.uv = v.uv;
            o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
            o.screenPosition = ComputeScreenPos(positionCS);
            o.tangentWS = normalize(TransformObjectToWorldDir(v.tangentOS.xyz));
            o.bitangentWS = normalize(cross(o.normalWS, o.tangentWS) * v.tangentOS.w);
            o.color = v.color;

            return o;
        }

        half3 CalculateBxDFResult(
            float3 normalWS,
            float3 lightDirectionWS,
            float3 viewDirectionWS,
            half3 albedo,
            half3 lightColor,
            float smoothness,
            float metallic,
            float shadow,
            bool isAdditionalLight)
        {
            float3 halfDirectionWS = normalize(viewDirectionWS + lightDirectionWS);

            float NoL = max(saturate(dot(normalWS, lightDirectionWS)), 0.000001);
            float NoV = max(saturate(dot(normalWS, viewDirectionWS)), 0.000001);
            float VoH = max(saturate(dot(viewDirectionWS, halfDirectionWS)), 0.000001);
            float NoH = max(saturate(dot(normalWS, halfDirectionWS)), 0.000001);

            float perceptualRoughness = 1.0 - smoothness;
            float roughness = perceptualRoughness * perceptualRoughness;

            float D = D_GGX_Custom(NoH, roughness);
            float G = G_Smith_Custom(NoL, NoV, roughness);

            float3 F0 = lerp(kDielectricSpec.rgb, albedo, metallic);
            float3 F = FresnelSchlick(VoH, F0);

            float3 specularResult = (D * G * F) / (4.0 * NoV * NoL);
            float3 specularColor = specularResult * lightColor * NoL * PI;

            float3 kd = (1.0 - F) * (1.0 - metallic);
            float3 diffuseColor = kd * albedo * lightColor * NoL;

            float3 directLightResult = diffuseColor + specularColor;

            float3 indirectResult = 0.0;
            if (!isAdditionalLight)
            {
                indirectResult = CalculateIBLResult(
                    normalWS,
                    viewDirectionWS,
                    albedo,
                    F0,
                    specularResult,
                    smoothness,
                    roughness,
                    perceptualRoughness,
                    metallic,
                    NoV
                );
            }

            float3 finalResult = directLightResult * shadow + indirectResult;
            return finalResult;
        }
        
        float D_Charlie_Fur(float NoH, float roughness)
        {
            roughness = max(roughness, 0.02);

            float invAlpha = 1.0 / roughness;
            float cos2h = NoH * NoH;
            float sin2h = max(1.0 - cos2h, 0.0078125);

            return (2.0 + invAlpha) * pow(sin2h, invAlpha * 0.5) / (2.0 * PI);
        }

        float V_Neubelt_Fur(float NoV, float NoL)
        {
            return 1.0 / max(4.0 * (NoL + NoV - NoL * NoV), 0.000001);
        }

        float FabricScatterFresnelLerp(float NoV, float scale)
        {
            float t0 = Pow4(1.0 - NoV);
            float t1 = 0.4 * (1.0 - NoV);
            return (t1 - t0) * scale + t0;
        }

        float3 CalculateIBLResult_Fur(
            float3 normalWS,
            float3 viewDirectionWS,
            half3 albedo,
            float3 F0,
            float smoothness,
            float roughness,
            float perceptualRoughness,
            float metallic,
            float NoV)
        {
            half3 ambientContrib = SampleSH(normalWS);
            float3 ambient = 0.03 * albedo;

            float3 iblDiffuse = max(half3(0, 0, 0), ambient.rgb + ambientContrib);

            float3 finalFresnel = FresnelSchlickRoughness(max(NoV, 0.0), F0, roughness);
            float3 kdLast = (1.0 - finalFresnel) * (1.0 - metallic);

            float mipRoughness = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);
            float3 reflectVector = reflect(-viewDirectionWS, normalWS);

            half mip = mipRoughness * UNITY_SPECCUBE_LOD_STEPS;
            half4 rgbm = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectVector, mip);
            float3 iblSpecular = DecodeHDREnvironment(rgbm, unity_SpecCube0_HDR);

            float surfaceReduction = 1.0 / (roughness * roughness + 1.0);

            float scatterFresnel = FabricScatterFresnelLerp(NoV, 0.5);
            float3 indirectSpecularFresnel = lerp(F0, 1.0, scatterFresnel);

            float3 indirectDiffuse = iblDiffuse * kdLast * albedo;
            float3 indirectSpecular = iblSpecular * surfaceReduction * indirectSpecularFresnel;

            return indirectDiffuse + indirectSpecular;
        }
        
        half3 CalculateBxDFResult_Fur(
        float3 normalWS,
        float3 lightDirectionWS,
        float3 viewDirectionWS,
        half3 albedo,
        half3 lightColor,
        float smoothness,
        float metallic,
        float shadow,
        bool isAdditionalLight)
    {
        float3 halfDirectionWS = normalize(viewDirectionWS + lightDirectionWS);

        float NoL = max(saturate(dot(normalWS, lightDirectionWS)), 0.000001);
        float NoV = max(saturate(dot(normalWS, viewDirectionWS)), 0.000001);
        float VoH = max(saturate(dot(viewDirectionWS, halfDirectionWS)), 0.000001);
        float NoH = max(saturate(dot(normalWS, halfDirectionWS)), 0.000001);

        float perceptualRoughness = 1.0 - smoothness;
        float roughness = perceptualRoughness * perceptualRoughness;

        float D = D_Charlie_Fur(NoH, roughness);
        float V = V_Neubelt_Fur(NoV, NoL);

        float3 F0 = lerp(kDielectricSpec.rgb, albedo, metallic);
        float3 F = FresnelSchlick(VoH, F0);

        float3 specularResult = D * V * F;
        float3 specularColor = specularResult * lightColor * NoL;

        float3 kd = (1.0 - F) * (1.0 - metallic);
        float3 diffuseColor = kd * albedo * lightColor * NoL;

        float3 directLightResult = diffuseColor + specularColor;

        float3 indirectResult = 0.0;
        if (!isAdditionalLight)
        {
            indirectResult = CalculateIBLResult_Fur(
                normalWS,
                viewDirectionWS,
                albedo,
                F0,
                smoothness,
                roughness,
                perceptualRoughness,
                metallic,
                NoV
            );
        }

        float3 finalResult = directLightResult * shadow + indirectResult;
        return finalResult;
    }

        float3 NormalBlendReoriented(float3 normalA, float3 normalB)
        {
            float3 t = normalA.xyz + float3(0.0, 0.0, 1.0);
            float3 u = normalB.xyz * float3(-1.0, -1.0, 1.0);
            return (t / t.z) * dot(t, u) - u;
        }

        half4 Frag(VertexOutput i) : SV_TARGET
        {
            float2 mainTexUV = i.uv * _MainTex_ST.xy + _MainTex_ST.zw;
            half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainTexUV);
            albedo.rgb *= _ColorTint.rgb;

            float3x3 TBN = float3x3(i.tangentWS, i.bitangentWS, i.normalWS);
            float2 normalUV = i.uv * _NormalMap_ST.xy + _NormalMap_ST.zw;
            float4 packedNormal = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, normalUV);
            float3 normalTS = UnpackScaleNormalCustom(packedNormal, _NormalInt);

            float3 normalWS = normalize(mul(normalTS, TBN));
            float3 viewDirectionWS = normalize(_WorldSpaceCameraPos.xyz - i.positionWS.xyz);

            float4 metallicSmoothnessTex = SAMPLE_TEXTURE2D(_MetallicSmoothnessTex, sampler_MetallicSmoothnessTex, i.uv).rgba;
            float metallic = metallicSmoothnessTex.r * _Metallic;
            float smoothness = metallicSmoothnessTex.a * _Smoothness;

            float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);

            Light mainLight = GetMainLight(shadowCoord);
            half3 mainLightColor = mainLight.color;
            float3 mainLightDirectionWS = mainLight.direction;
            float mainLightShadow = MainLightRealtimeShadow(shadowCoord);
            float3 mainLightRadiance = mainLightColor * mainLight.distanceAttenuation;

            half3 mainColor = CalculateBxDFResult(
                normalWS,
                mainLightDirectionWS,
                viewDirectionWS,
                albedo.rgb,
                mainLightRadiance,
                smoothness,
                metallic,
                mainLightShadow,
                false
            );

            uint lightCount = GetAdditionalLightsCount();
            half3 additionalColor = half3(0, 0, 0);
            for (uint lightIndex = 0; lightIndex < lightCount; lightIndex++)
            {
                Light additionalLight = GetAdditionalLight(lightIndex, i.positionWS.xyz, 1);
                half3 additionalLightColor = additionalLight.color;
                float3 additionalLightDirectionWS = additionalLight.direction;
                float3 additionalLightRadiance = additionalLightColor * additionalLight.distanceAttenuation;

                additionalColor += CalculateBxDFResult(
                    normalWS,
                    additionalLightDirectionWS,
                    viewDirectionWS,
                    albedo.rgb,
                    additionalLightRadiance,
                    smoothness,
                    metallic,
                    additionalLight.shadowAttenuation,
                    true
                );
            }

            half3 finalRGB = mainColor + additionalColor;
            return half4(finalRGB, 1.0);
        }

        VertexOutputFur VertFur(VertexInputFur v)
        {
            VertexOutputFur o;

            float loopTimes = max((float)_LoopTimes, 1.0);
            float furShellOffset = (float)_LoopIndex * rcp(loopTimes);

            float3 gravityDirectionOS = normalize(TransformWorldToObjectDir(float3(0.0, -1.0, 0.0)));

            float gravityWeight = furShellOffset * furShellOffset;

            float3 furDirectionOS = normalize(v.normalOS + gravityDirectionOS * _GravityStrength * gravityWeight);
            float3 furPositionOS = v.positionOS.xyz + furDirectionOS * furShellOffset * _FurLength;

            o.positionCS = TransformObjectToHClip(furPositionOS);
            o.normalWS = TransformObjectToWorldNormal(v.normalOS);
            o.uv = v.uv;
            o.positionWS = TransformObjectToWorld(furPositionOS);

            return o;
        }

        half4 FragFur(VertexOutputFur i) : SV_TARGET
        {
            float2 mainTexUV = i.uv * _MainTex_ST.xy + _MainTex_ST.zw;
            half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainTexUV);

            float furNoise = SAMPLE_TEXTURE2D(_FurNoise, sampler_FurNoise, i.uv * _FurNoise_ST.xy + _FurNoise_ST.zw).r;
            float furOffset = ((float)_LoopIndex + 0.1) * rcp(max((float)_LoopTimes, 1.0));
            float alphaMask = step(furOffset*furOffset, furNoise);
            float alpha = saturate(1.0 - furOffset);

            float3 normalWS = NormalizeNormalPerPixel(i.normalWS);
            float3 viewDirectionWS = normalize(_WorldSpaceCameraPos.xyz - i.positionWS.xyz);

            float4 metallicSmoothnessTex = SAMPLE_TEXTURE2D(_MetallicSmoothnessTex, sampler_MetallicSmoothnessTex, i.uv).rgba;
            float metallic = metallicSmoothnessTex.r * _Metallic;
            float smoothness = metallicSmoothnessTex.a * _Smoothness;

            float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);

            Light mainLight = GetMainLight(shadowCoord);
            half3 mainLightColor = mainLight.color;
            float3 mainLightDirectionWS = mainLight.direction;
            float mainLightShadow = MainLightRealtimeShadow(shadowCoord);
            float3 mainLightRadiance = mainLightColor * mainLight.distanceAttenuation;

            #if defined(_USE_FUR_BXDF)
            half3 mainColor = CalculateBxDFResult_Fur(
                normalWS,
                mainLightDirectionWS,
                viewDirectionWS,
                albedo.rgb,
                mainLightRadiance,
                smoothness,
                metallic,
                mainLightShadow,
                false
            );
            #else
                half3 mainColor = CalculateBxDFResult(
                    normalWS,
                    mainLightDirectionWS,
                    viewDirectionWS,
                    albedo.rgb,
                    mainLightRadiance,
                    smoothness,
                    metallic,
                    mainLightShadow,
                    false
                );
            #endif

            uint lightCount = GetAdditionalLightsCount();
            half3 additionalColor = half3(0, 0, 0);
            for (uint lightIndex = 0; lightIndex < lightCount; lightIndex++)
            {
                Light additionalLight = GetAdditionalLight(lightIndex, i.positionWS.xyz, 1);
                half3 additionalLightColor = additionalLight.color;
                float3 additionalLightDirectionWS = additionalLight.direction;
                float3 additionalLightRadiance = additionalLightColor * additionalLight.distanceAttenuation;

                #if defined(_USE_FUR_BXDF)
                additionalColor += CalculateBxDFResult_Fur(
                    normalWS,
                    additionalLightDirectionWS,
                    viewDirectionWS,
                    albedo.rgb,
                    additionalLightRadiance,
                    smoothness,
                    metallic,
                    additionalLight.shadowAttenuation,
                    true
                );
            #else
                additionalColor += CalculateBxDFResult(
                    normalWS,
                    additionalLightDirectionWS,
                    viewDirectionWS,
                    albedo.rgb,
                    additionalLightRadiance,
                    smoothness,
                    metallic,
                    additionalLight.shadowAttenuation,
                    true
                );
            #endif
            }

            half3 finalRGB = (mainColor + additionalColor) * _FurColor.rgb;

            clip(alphaMask - 0.5h);

            return half4(finalRGB, alpha);
        }

        ENDHLSL

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }

            Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "Meta" }

            Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "Fur" }

            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex VertFur
            #pragma fragment FragFur
            ENDHLSL
        }
    }
}