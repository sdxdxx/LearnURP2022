//This is a shader used in Unity's RenderFeature to create the Ray Marching Clouds, and it refers to Beer-Lambert Law and the physical formula of Mie scattering and Rayleigh scattering
Shader "URP/PostProcessing/Clouds"
{
    Properties
    {
        
    }
    
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "RenderPipeline" = "UniversalPipeline"  
        }
        
        Cull Off 
        ZWrite Off
        ZTest Always
        
        HLSLINCLUDE
           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
           #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            #include  "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            
            //----------Texture-----------
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_MyDepthTex);
            SAMPLER(sampler_MyDepthTex);
            TEXTURE3D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);
            TEXTURE3D(_DetailNoiseTex);
            SAMPLER(sampler_DetailNoiseTex);
            TEXTURE2D(_MaskNoise);
            SAMPLER(sampler_MaskNoise);
            TEXTURE2D(_BlueNoise);
            SAMPLER(sampler_BlueNoise);
            TEXTURE2D(_WeatherMap);
            SAMPLER(sampler_WeatherMap);
            //----------Texture-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------Variable-----------
            float3 _CloudsPos;
            float3 _CloudsBound;

            float _SkyMaskValue;
            
            float _StepTime;
            float _NosieTexScale;
            float _DetailNosieTexScale;
            float3 _NoiseTexOffset;
            float4 _BlueNoiseTillingOffset;
            
            float4 _shapeNoiseWeights;
            float _detailWeights;
            float _detailNoiseWeight;
            float _rayOffsetStrength;
            
            half4 _colA;
            half4 _colB;
            float _colorOffset1;
            float _colorOffset2;
            float _lightAbsorptionTowardSun;
            float4 _phaseParams;

            float _densityOffset;
            float _densityMultiplier;
            float _heightWeights;
            
            half4 _BaseColor;

            float _WeatherMapScale;
            float4 _xy_Speed_zw_Warp;
            float2 _xy_WeatherSpeed;
            //----------Variable-----------
            CBUFFER_END

            #define random(seed) sin(seed * 641.5467987313875 + 1.943856175)

            //Remap
            float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
             {
               return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
             }
            
            //Reconstruct World Position
            float3 ReconstructWorldPositionFromDepth01(float2 screenPos, float depth01)
            {
                float2 ndcPos = screenPos*2-1;//map[0,1] -> [-1,1]
                float3 clipPos = float3(ndcPos.x,ndcPos.y,1)*_ProjectionParams.z;// z = far plane = mvp result w
                float3 viewPos = mul(unity_CameraInvProjection,clipPos.xyzz).xyz * depth01;
                float3 worldPos = mul(UNITY_MATRIX_I_V,float4(viewPos,1)).xyz;
                return worldPos;
            }
           
           float3 ReconstructWorldPositionFromRawDepth(float2 screenPos, float rawDepth)
            {
                float2 ndcPos = screenPos * 2 - 1;
                float4 clipPos = float4(ndcPos.x, ndcPos.y, rawDepth, 1.0);
                float4 viewPosH = mul(unity_CameraInvProjection, clipPos);
                float3 viewPos = viewPosH.xyz / viewPosH.w;
                float3 worldPos = mul(UNITY_MATRIX_I_V, float4(viewPos, 1.0)).xyz;
                return worldPos;
            }
           
           
            float2 rayBoxDst(float3 boundsMin, float3 boundsMax, float3 rayOrigin, float3 invRaydir) 
            {
                float3 t0 = (boundsMin - rayOrigin) * invRaydir;
                float3 t1 = (boundsMax - rayOrigin) * invRaydir;
                float3 tmin = min(t0, t1);
                float3 tmax = max(t0, t1);

                float dstA = max(max(tmin.x, tmin.y), tmin.z); //Entry Point
                float dstB = min(tmax.x, min(tmax.y, tmax.z)); //Exit Point

                float dstToBox = max(0, dstA);
                float dstInsideBox = max(0, dstB - dstToBox);
                return float2(dstToBox, dstInsideBox);
            }

            float sampleDensity(float3 sampleTexcoord, float3 boundMin, float3 boundMax) 
            {
                float3 size = boundMax - boundMin;
                float3 boundsCentre = (boundMax + boundMin) * 0.5;
                float speedShape = _Time.y * _xy_Speed_zw_Warp.x;
                float speedDetail = _Time.y * _xy_Speed_zw_Warp.y;
                float2 speedWeather = _Time.y*_xy_WeatherSpeed;
                
                float2 uv = (size.xz * 0.5f + (sampleTexcoord.xz - boundsCentre.xz) ) /max(size.x,size.z);//Calculate the UV on the XZ plane of the cloud block box
                float4 maskNoise = SAMPLE_TEXTURE2D_LOD(_MaskNoise, sampler_MaskNoise, uv + float2(speedShape * 0.5,0), 0);

                //Sample 3D Noise
                float3 uvwShape = sampleTexcoord  * _NosieTexScale + float3(speedShape, speedShape * 0.2,0)+_NoiseTexOffset;
                float3 uvwDetail = sampleTexcoord * _DetailNosieTexScale + float3(speedDetail, speedDetail * 0.2,0);

                //Sample Weather Map
                float4 weatherMap = SAMPLE_TEXTURE2D_LOD(_WeatherMap, sampler_WeatherMap, frac(uv * _WeatherMapScale + speedWeather*0.2 ), 0);
                float heightPercent = (sampleTexcoord.y - boundMin.y) / size.y;//Calculate a gradient value
                float gMin = remap(weatherMap.x, 0, 1, 0.1, 0.5);
                float gMax = remap(weatherMap.x, 0, 1, gMin, 0.9);
                float heightGradient = saturate(remap(heightPercent, 0.0, gMin, 0, 1))
                * saturate(remap(heightPercent, 1, gMax, 0, 1));
                float heightGradient2 = saturate(remap(heightPercent, 0.0, weatherMap.r, 1, 0))
                * saturate(remap(heightPercent, 0.0, gMin, 0, 1));
                heightGradient = saturate(lerp(heightGradient, heightGradient2,_heightWeights));
                
                //Border density attenuation
                const float containerEdgeFadeDst = 10;
                float dstFromEdgeX = min(containerEdgeFadeDst, min(sampleTexcoord.x - boundMin.x, boundMax.x - sampleTexcoord.x));
                float dstFromEdgeZ = min(containerEdgeFadeDst, min(sampleTexcoord.z - boundMin.z, boundMax.z - sampleTexcoord.z));
                float edgeWeight = min(dstFromEdgeZ, dstFromEdgeX) / containerEdgeFadeDst;
                heightGradient = heightGradient*edgeWeight;
                
                float4 normalizedShapeWeights = _shapeNoiseWeights / dot(_shapeNoiseWeights, 1);
                float4 shapeNoise = SAMPLE_TEXTURE3D_LOD(_NoiseTex,sampler_NoiseTex,frac(uvwShape + (maskNoise.r * _xy_Speed_zw_Warp.z * 0.1)),0);
                float4 detailNoise = SAMPLE_TEXTURE3D_LOD(_DetailNoiseTex,sampler_NoiseTex,frac(uvwDetail + (maskNoise.r * _xy_Speed_zw_Warp.w * 0.1)),0);
                float shapeFBM = dot(shapeNoise, normalizedShapeWeights)*heightGradient;
                float baseShapeDensity = shapeFBM + _densityOffset * 0.01;

                if (baseShapeDensity > 0)
                  {
                    float detailFBM = pow(detailNoise.g, _detailWeights);
                    float oneMinusShape = 1 - baseShapeDensity;
                    float detailErodeWeight = oneMinusShape * oneMinusShape * oneMinusShape;
                    float cloudDensity = baseShapeDensity - detailFBM * detailErodeWeight * _detailNoiseWeight;
                    float densityMultiplier = max(0,_densityMultiplier);
                    return saturate(cloudDensity * densityMultiplier);
                  }
                
                 return 0;
             }

            float hg(float a, float g) 
            {
                float g2 = g * g;
                return (1 - g2) / (4 * 3.1415 * pow(1 + g2 - 2 * g * (a), 1.5));
            }
            
            float phase(float a) 
            {
                float blend = 0.5;
                float hgBlend = hg(a, _phaseParams.x) * (1 - blend) + hg(a, -_phaseParams.y) * blend;
                return _phaseParams.z + hgBlend * _phaseParams.w;
            }

            float3 lightmarch(float3 position , float3 boundMin, float3 boundMax)
            {
                float3 dirToLight = _MainLightPosition.xyz;
                dirToLight.y = remap(dirToLight.y,-1,1,0.2,1);
                
               //Intersection between the direction of the light and the bounding box, excluding any excess
               float dstInsideBox = rayBoxDst(boundMin, boundMax, position, 1 / dirToLight).y;
               float stepSize = dstInsideBox / 10;
               float totalDensity = 0;

              for (int step = 0; step < 8; step++) //Number of lighting steps
              { 
                 position += dirToLight * stepSize; //Step towards the light

                 //Sampling noise during stepping, cumulative density affected by lighting
                 totalDensity += max(0, sampleDensity(position,boundMin,boundMax) * stepSize);
              }
                
                float transmittance = exp(-totalDensity * _lightAbsorptionTowardSun);
                transmittance  = max(0.3+0.1*transmittance,transmittance);

              //Map light to dark as 3 colors, brightness ->light color, middle ->ColorA, darkness ->ColorB
              float3 cloudColor = lerp(_colA, _MainLightColor, saturate(transmittance * _colorOffset1));
              cloudColor = lerp(_colB, cloudColor, saturate(pow(transmittance * _colorOffset2, 3)));
              return  transmittance * cloudColor*_BaseColor;
            }

            float4 cloudRayMarching(float3 worldViewDir, float rawDepth, float2 screenPos)
            {
                float3 boundMax = _CloudsPos +_CloudsBound/2;
                float3 boundMin = _CloudsPos -_CloudsBound/2;
                
                float2 rayToContainerInfo = rayBoxDst(boundMin, boundMax, _WorldSpaceCameraPos, rcp(worldViewDir));

                float3 blueNoise = SAMPLE_TEXTURE2D_LOD(_BlueNoise, sampler_BlueNoise, screenPos*_BlueNoiseTillingOffset.xy+_BlueNoiseTillingOffset.zw+_Time.x, 0);

                float depthEyeLinear = LinearEyeDepth(rawDepth,_ZBufferParams);
                float depth01Linear = Linear01Depth(rawDepth,_ZBufferParams);
                float skyMask = step(_SkyMaskValue,depth01Linear);
                float dstToBox = rayToContainerInfo.x; //The distance From Camera to Box
                float dstInsideBox = rayToContainerInfo.y; //if the Ray is in the Box
                float dstLimit = min(depthEyeLinear - dstToBox, dstInsideBox);
                //The distance from the camera to the object - the distance from the camera to the box,
                //where the minimum value is taken based on whether the light is in the Box,
                //and some invalid values are filtered out

                //The scattering towards the direction of the light is stronger
                float cosAngle = dot(worldViewDir, _MainLightPosition.xyz);
                float3 phaseVal = phase(cosAngle);

                float3 entryPoint = _WorldSpaceCameraPos + worldViewDir * dstToBox;
                float3 endPoint = entryPoint + worldViewDir * dstLimit;
                float3 lightEnergy = 0;
                float sumLightTransmittanceIntensity = 1;//Accumulated clouds density
                float dstTravelled = blueNoise*_rayOffsetStrength;//Add perturbation processing layer

                float stepTime = _StepTime;
                float rayStep = dstLimit/stepTime;

                float seed = random((_ScreenParams.y * screenPos.y + screenPos.x) * _ScreenParams.x);

                // Core
                if (skyMask)//SkyMask
                {
                    for (int j = 0; j < stepTime ; j++)
                    {
                        float3 sampleTexcoord = entryPoint + (worldViewDir * (dstTravelled+seed*rayStep));
                        float density = sampleDensity(sampleTexcoord,boundMin,boundMax);
                        if (density>0)
                        {
                            float3 lightTransmittance = lightmarch(sampleTexcoord, boundMin, boundMax);
                            lightEnergy += density * rayStep * sumLightTransmittanceIntensity * lightTransmittance *phaseVal;
                            
                            sumLightTransmittanceIntensity *= exp(-density *rayStep);
                            //The transmittance intensity decreases exponentially with
                            //the increase of the density of the medium and the distance of light propagation.
                            //The smaller the transmittance intensity, the thicker the fog
                            
                            if (sumLightTransmittanceIntensity < 0.01f)
                            {
                                break;
                            }
                        }
                        dstTravelled += rayStep; //Step length each time
                    }
                }
                
                return float4(lightEnergy,1-sumLightTransmittanceIntensity);
            }
        ENDHLSL
        
        //CalculateCloud
        pass
        {
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag_Cloud
            
            half4 frag_Cloud (Varyings i) : SV_TARGET
            {

                float2 screenPos = i.texcoord;
                
                float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp,screenPos).r;
                float linear01Depth = Linear01Depth(rawDepth,_ZBufferParams);
                
                float3 posWS_Frag = ReconstructWorldPositionFromDepth01(screenPos,linear01Depth);

                float3 worldViewDir = normalize(posWS_Frag.xyz - _WorldSpaceCameraPos.xyz);
                
                float4 cloud = cloudRayMarching(worldViewDir,rawDepth,screenPos);

                half4 result = cloud;
                
                return result;
            }
            
            ENDHLSL
        }
        

        //Blur Vertical
        Pass
        {
            Cull Off 
            ZWrite Off
            
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag
            
            //----------贴图声明开始-----------

            //----------贴图声明结束-----------

            float4 _BlitTexture_TexelSize;
            float _BlurRange;
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            
            //----------变量声明结束-----------
            CBUFFER_END
            
            
            half4 frag (Varyings i) : SV_TARGET
            {
                float2 uv = i.texcoord;
                float blurSize = lerp(0.0f,5.0f,_BlurRange);
                //设置垂直方向的采样坐标
                float2 uv_vertical[5];
                uv_vertical[0] = uv + float2(0.0, _BlitTexture_TexelSize.y * 2.0) * blurSize;
                uv_vertical[1] = uv + float2(0.0, _BlitTexture_TexelSize.y * 1.0) * blurSize;
                uv_vertical[2] = uv;
                uv_vertical[3] = uv - float2(0.0, _BlitTexture_TexelSize.y * 1.0) * blurSize;
                uv_vertical[4] = uv - float2(0.0, _BlitTexture_TexelSize.y * 2.0) * blurSize;
                
                //weight
                float weight[5] = { 0.0545,0.2442,0.4026, 0.2442, 0.0545};

                //中心纹理*权重
                half4 sum = half4(0,0,0,0);
                //上下/左右 的2个纹理*权重
                sum += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,uv_vertical[0]) * weight[0];
                sum += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,uv_vertical[1]) * weight[1];
                sum += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,uv_vertical[2]) * weight[2];
                sum += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,uv_vertical[3]) * weight[3];
                sum += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,uv_vertical[4]) * weight[4];
                half4 col = sum;
                return col*_BaseColor;
            }
            
            ENDHLSL
        }

        //Blur Horizontal
        Pass
        {
            Cull Off 
            ZWrite Off
            
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
           #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            #include  "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            
            //----------贴图声明开始-----------
            
            //----------贴图声明结束-----------
            float4 _BlitTexture_TexelSize;
            float _BlurRange;
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------

            //----------变量声明结束-----------
            CBUFFER_END
            
            
            half4 frag (Varyings i) : SV_TARGET
            {
                float2 uv = i.texcoord;
                float blurSize = lerp(0.0f,5.0f,_BlurRange);
                //设置水平方向的采样坐标
                float2 uv_horizontal[5];
                uv_horizontal[0] = uv + float2(_BlitTexture_TexelSize.x * 2.0, 0.0) * blurSize;
                uv_horizontal[1] = uv + float2(_BlitTexture_TexelSize.x * 1.0, 0.0) * blurSize;
                uv_horizontal[2] = uv;
                uv_horizontal[3] = uv - float2(_BlitTexture_TexelSize.x * 1.0, 0.0) * blurSize;
                uv_horizontal[4] = uv - float2(_BlitTexture_TexelSize.x * 2.0, 0.0) * blurSize;

                //weight
                float weight[5] = { 0.0545,0.2442,0.4026, 0.2442, 0.0545};

                //中心纹理*权重
                half4 sum = half4(0,0,0,0);
                //上下/左右 的2个纹理*权重
                sum += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,uv_horizontal[0]) * weight[0];
                sum += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,uv_horizontal[1]) * weight[1];
                sum += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,uv_horizontal[2]) * weight[2];
                sum += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,uv_horizontal[3]) * weight[3];
                sum += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp,uv_horizontal[4]) * weight[4];
                half4 col = sum;
                return col*_BaseColor;
            }
            
            ENDHLSL
        }
        
         pass
        {
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag_Composite

            TEXTURE2D(_CloudMap);
            SAMPLER(sampler_CloudMap);
            
            half4 frag_Composite (Varyings i) : SV_TARGET
            {
                half4 albedo =  SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);
                
                float intensity = remap(_MainLightPosition.y,-1,1,0.3,1);

                half4 cloud = SAMPLE_TEXTURE2D(_CloudMap,sampler_CloudMap,i.texcoord);
                
                half3 FinalRGB = albedo.rgb*(1-cloud.a)+cloud.a*cloud.rgb*_BaseColor*intensity;
                
                half4 result = half4(FinalRGB,1.0);
                
                return result;
            }
            
            ENDHLSL
        }
    }
}