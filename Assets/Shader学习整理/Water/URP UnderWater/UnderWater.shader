Shader "URP/PostProcessing/UnderWater"
{
    Properties
    {
    }

    SubShader
    {
        Tags
        {
            "RenderType"     = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        Cull Off
        ZWrite Off
        ZTest Always

        //==========================================================================
        // Pass 0: WaterMask
        //==========================================================================
        Pass
        {
            Name "WaterMask"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

            CBUFFER_START(UnityPerMaterial)
                //----------变量声明开始-----------
                half4 _BaseColor;
                //----------变量声明结束-----------
            CBUFFER_END

            struct vertexInput
            {
                float4 vertex  : POSITION;
                float3 normal  : NORMAL;
                float4 tangent : TANGENT;
                float2 uv      : TEXCOORD0;
            };

            struct vertexOutput
            {
                float4 pos   : SV_POSITION;
                float2 uv    : TEXCOORD0;
                float3 nDirWS: TEXCOORD1;
            };

            vertexOutput vert(vertexInput v)
            {
                vertexOutput o;
                o.pos    = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv     = v.uv;
                return o;
            }

            half4 frag(vertexOutput i) : SV_TARGET
            {
                return half4(1, 1, 1, 1);
            }
            ENDHLSL
        }

        //==========================================================================
        // Pass 1: UnderWater
        //==========================================================================
        Pass
        {
            Name "UnderWater"

            HLSLPROGRAM
            #pragma vertex   Vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            //--------------------------------------------------------------------------
            // Textures / Samplers
            //--------------------------------------------------------------------------
            //----------贴图声明开始-----------
            TEXTURE2D(_CameraOpaqueTexture);              // 获取到摄像机渲染画面的Texture
            SAMPLER(sampler_CameraOpaqueTexture);

            TEXTURE2D(_m_CameraDepthTexture);
            TEXTURE2D(_m_CameraNormalsTexture);

            TEXTURE2D(_DistorationNoise);
            SAMPLER(sampler_DistorationNoise);

            TEXTURE2D(_CausticsTexture);
            SAMPLER(sampler_CausticsTexture);
            //----------贴图声明结束-----------

            //--------------------------------------------------------------------------
            // Per-Material Parameters
            //--------------------------------------------------------------------------
            CBUFFER_START(UnityPerMaterial)
                //----------变量声明开始-----------
                int   _isEditorGlobalMode;

                half4 _UnderWaterDeepColor;
                half4 _UnderWaterShallowColor;
                half4 _UnderWaterFogColor;
                float _UnderWaterFogDensityMin;
                float _UnderWaterFogDensityMax;

                float2 _DistorationNoise_Tilling;
                float  _DistorationIntensity;
                float  _DistorationSpeed;

                float3 _ViewPortPos[4];
                float  _WaterPlaneHeight;

                float  _UnderWaterLineWidth;
                float  _WaterLineSmooth;
                float  _WaterLineOffset;
                half4  _WaterLineColor;

                float4 _WaveA;
                float4 _WaveB;
                float4 _WaveC;
                float  _WaveInt;

                float  _CausticsTextureScale;
                float  _CausticsSpeed;
                float  _CausticsIntensity;
                //----------变量声明结束-----------
            CBUFFER_END

            //--------------------------------------------------------------------------
            // Utility: Reconstruct WS Position from Depth
            //--------------------------------------------------------------------------
            float3 ReconstructWorldPositionFromDepth(float2 screenPos, float rawDepth)
            {
                float2 ndcPos = screenPos * 2 - 1; // map[0,1] -> [-1,1]
                float3 worldPos;

                if (unity_OrthoParams.w)
                {
                    float depth01  = 1 - rawDepth;
                    float3 viewPos = float3(unity_OrthoParams.xy * ndcPos.xy, 0);
                    viewPos.z      = -lerp(_ProjectionParams.y, _ProjectionParams.z, depth01);
                    worldPos       = mul(UNITY_MATRIX_I_V, float4(viewPos, 1)).xyz;
                }
                else
                {
                    float depth01  = Linear01Depth(rawDepth, _ZBufferParams);
                    float3 clipPos = float3(ndcPos.x, ndcPos.y, 1) * _ProjectionParams.z; // z = far plane = mvp result w
                    float3 viewPos = mul(unity_CameraInvProjection, clipPos.xyzz).xyz * depth01;
                    worldPos       = mul(UNITY_MATRIX_I_V, float4(viewPos, 1)).xyz;
                }

                return worldPos;
            }

            //--------------------------------------------------------------------------
            // Utility: Gerstner Wave
            //--------------------------------------------------------------------------
            float3 GerstnerWave(float4 wave, float3 p)
            {
                float steepness  = wave.z;
                float wavelength = wave.w;

                float  k = 2 * PI / wavelength;
                float  c = sqrt(9.8 / k);
                float2 d = normalize(wave.xy);

                float f = k * (dot(d, p.xz) - c * _Time.y);
                float a = steepness / k;

                p.x += d.x * (a * cos(f));
                p.y  = a * sin(f);
                p.z += d.y * (a * cos(f));

                return float3(
                    d.x * (a * cos(f)),
                    a * sin(f),
                    d.y * (a * cos(f))
                );
            }

            //--------------------------------------------------------------------------
            // Fragment
            //--------------------------------------------------------------------------
            half4 frag(Varyings i) : SV_TARGET
            {
                half4 albedo = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);

                //==============================================================
                // 1) UnderWaterMask (基于 ViewPort WS + WaterPlane + GerstnerWave)
                //==============================================================
                float3 xDir          = _ViewPortPos[1] - _ViewPortPos[0];
                float3 yDir          = _ViewPortPos[2] - _ViewPortPos[0];
                float3 viewPortFragWS= _ViewPortPos[0] + i.texcoord.x * xDir + i.texcoord.y * yDir;

                float3 waterPoint = float3(viewPortFragWS.x, _WaterPlaneHeight, viewPortFragWS.z);
                waterPoint += GerstnerWave(_WaveA, waterPoint) * _WaveInt;
                waterPoint += GerstnerWave(_WaveB, waterPoint) * _WaveInt;
                waterPoint += GerstnerWave(_WaveC, waterPoint) * _WaveInt;

                waterPoint.y += _WaterLineOffset * 0.1f;

                float underWaterMask0 = 1 - step(waterPoint.y, viewPortFragWS.y);

                //==============================================================
                // 2) WaterLine
                //==============================================================
                float waterLine_y1     = waterPoint.y - 0.001 * _UnderWaterLineWidth / 2;
                float underWaterMask1  = smoothstep(waterLine_y1, waterLine_y1 - _WaterLineSmooth * 0.02, viewPortFragWS.y);

                float waterLine_y2     = waterPoint.y + 0.001 * _UnderWaterLineWidth / 2;
                float underWaterMask2  = smoothstep(waterLine_y2, waterLine_y2 + _WaterLineSmooth * 0.02, viewPortFragWS.y);

                float waterLine        = 1 - abs(underWaterMask1 - underWaterMask2);

                //==============================================================
                // 3) UnderWaterColor (depth + distortion + fog)
                //==============================================================
                float m_rawDepth   = SAMPLE_TEXTURE2D(_m_CameraDepthTexture, sampler_PointClamp, i.texcoord);
                float m_linearDepth= LinearEyeDepth(m_rawDepth, _ZBufferParams);
                float m_depth01    = Linear01Depth(m_rawDepth, _ZBufferParams);

                if (unity_OrthoParams.w)
                {
                    m_depth01     = 1 - m_rawDepth;
                    m_linearDepth = lerp(_ProjectionParams.y, _ProjectionParams.z, m_depth01);
                }

                float2 distorationNoise = SAMPLE_TEXTURE2D(
                    _DistorationNoise,
                    sampler_DistorationNoise,
                    i.texcoord * _DistorationNoise_Tilling + _Time.y * 0.1 * _DistorationSpeed
                );

                float2 distorationUV = i.texcoord + distorationNoise / 5.0f * _DistorationIntensity;

                float m_rawDepth_distoration = SAMPLE_TEXTURE2D(_m_CameraDepthTexture, sampler_PointClamp, distorationUV);
                float m_depth01_distoration  = Linear01Depth(m_rawDepth_distoration, _ZBufferParams);

                if (unity_OrthoParams.w)
                {
                    m_depth01_distoration = 1 - m_rawDepth_distoration;
                }

                float waterDepth = _WaterPlaneHeight - viewPortFragWS.y;
                half3 waterCol   = lerp(_UnderWaterDeepColor, _UnderWaterShallowColor, exp(-waterDepth));

                float m_linearEyeDepth_distoration = LinearEyeDepth(m_rawDepth_distoration, _ZBufferParams);
                float depthFog = (_UnderWaterFogDensityMax - m_linearEyeDepth_distoration) /
                                 (_UnderWaterFogDensityMax - _UnderWaterFogDensityMin);
                depthFog = saturate(depthFog);

                half4 albedo_Distoration = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, distorationUV);
                float3 underWaterCol     = lerp(waterCol * _UnderWaterFogColor, albedo_Distoration, depthFog) * waterCol;

                //==============================================================
                // 4) Caustics
                //==============================================================
                float rawDepth_distoration = SAMPLE_TEXTURE2D(_m_CameraDepthTexture, sampler_PointClamp, distorationUV);
                float3 posWS_Frag_distoration = ReconstructWorldPositionFromDepth(distorationUV, rawDepth_distoration);

                float2 causticsUV  = posWS_Frag_distoration.xz / _CausticsTextureScale;
                float2 causticsUV1 = frac(causticsUV + _Time.x * _CausticsSpeed);
                float2 causticsUV2 = frac(causticsUV - _Time.x * _CausticsSpeed);

                half3 CausticsCol1 = SAMPLE_TEXTURE2D(_CausticsTexture, sampler_LinearRepeat, causticsUV1 + float2(0.1f, 0.2f));
                half3 CausticsCol2 = SAMPLE_TEXTURE2D(_CausticsTexture, sampler_LinearRepeat, causticsUV2);

                float3 CameraNormal = SAMPLE_TEXTURE2D(_m_CameraNormalsTexture, sampler_LinearRepeat, distorationUV);
                float  CausticsMask1= saturate(CameraNormal.y * CameraNormal.y);
                float  CausticsMask2= saturate(dot(CameraNormal, _MainLightPosition));
                float  CausticsMask = CausticsMask1 * CausticsMask2;

                half3 CausticsCol = min(CausticsCol1, CausticsCol2) * depthFog * _CausticsIntensity * CausticsMask;

                //==============================================================
                // 5) Composite
                //==============================================================
                half3 mainCol = saturate(underWaterCol + CausticsCol);
                half3 FinalRGB = 0;

                if (_isEditorGlobalMode > 0.5)
                {
                    FinalRGB = mainCol;
                }
                else
                {
                    mainCol  = lerp(albedo, mainCol, underWaterMask0);
                    FinalRGB = lerp(mainCol, saturate(_WaterLineColor * 0.9f + mainCol * 0.1f), waterLine);
                }

                return half4(FinalRGB, 1.0);
            }

            ENDHLSL
        }
    }
}
