Shader "URP/NPR/Genshin"
{
    Properties
    {
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _MainTex("MainTex",2D) = "white"{}
        _LightMap("Light Map",2D) = "black"{}
        
        [Header(ShadowAndAO)]
        _FaceShadowMap("Face Shadow Map",2D) = "black"{}
        _ShadowRampMap("Shadow Ramp Map",2D) = "white"{}
        _ShadowRampBias("Shadow Ramp Bias",Range(0,0.2)) = 0.2
        _AOIntensity("AO Intensity",Range(0,1)) = 0.5
        
        [Header(Specular)]
        _MetalMap("Metal Map",2D) = "black"{}
        _SpecularPow("Specular Power (Non Metallic)",Range(0,80)) = 50
        _SpecularInt("Specular Intensity (Non Metallic)",Range(0,2)) = 1
        _SpecularInt_Metallic("Specular Intensity (Metallic)",Range(0,3)) = 1
        
        [Header(Rim)]
        _RimCol ("Rim Color", Color) = (1, 1, 1, 1)
        _RimWidth ("Depth Rim Width", Float) = 0
        _FresnelPow("Fresnel Power", Range(0,8)) = 5 
        _RimInt("Rim Intensity",Range(0,2)) = 1.2
        
        [Header(Outline)]
        _OutlineColor("Outline Color",Color) = (0.0,0.0,0.0,0.0)
        _OutlineWidth("Outline Width",Range(0,5)) = 1
        
        [Header(Emission)]
        _EmissionTint("Emission Tint",Color) = (1.0,1.0,1.0,1.0)
        _EmissionInt("Emission Intensity",Range(0,2)) = 0
        
        [Toggle(_FACE_MODE)] _EnableRed ("ENABLE FACE MODE", Float) = 0
        [Toggle(_ALBEDO_MODE)] _EnableAlbedo ("ENABLE ALBEDO MODE", Float) = 0
    }
    
    SubShader
    {
         Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }
    	
    	//解决深度引动模式Depth Priming Mode问题
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/DepthNormals"
        UsePass "Universal Render Pipeline/Lit/SHADOWCASTER"

        pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }
            
            Cull Back
            
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature_local _FACE_MODE
            #pragma shader_feature_local _ALBEDO_MODE
            
            #pragma multi_compile  _MAIN_LIGHT_SHADOWS
			#pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile  _SHADOWS_SOFT
            
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);//定义贴图
            SAMPLER(sampler_MainTex);//定义采样器
            TEXTURE2D(_LightMap);//定义贴图
            SAMPLER(sampler_LightMap);//定义采样器
            TEXTURE2D(_FaceShadowMap);//定义贴图
            SAMPLER(sampler_FaceShadowMap);//定义采样器
            TEXTURE2D(_ShadowRampMap);//定义贴图
            SAMPLER(sampler_ShadowRampMap);//定义采样器
            TEXTURE2D(_MetalMap);//定义贴图
            SAMPLER(sampler_MetalMap);//定义采样器
            
            TEXTURE2D_X_FLOAT(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float4 _MainTex_ST;
            
            float _ShadowRampBias;
            float _AOIntensity;
            
            float _SpecularPow;
            float _SpecularInt;
            float _SpecularInt_Metallic;
            
            half4 _RimCol;
            float _RimWidth;
            float _FresnelPow;
            float _RimInt;
            
            float _EmissionInt;
            half3 _EmissionTint;
            
            //----------变量声明结束-----------
            CBUFFER_END

            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 positionOS: TEXCOORD2;
                float4 screenPos: TEXCOORD3;
                float4 color : TEXCOORD4;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.normalWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                o.screenPos = ComputeScreenPos(o.pos);
                o.positionOS = v.vertex.xyz;
                o.color = v.color;
                return o;
            }
            
            float GetLinearEyeDepth(float rawDepth)
            {
                float linearEyeDepth;
                // 正交投影处理 (Orthographic)
                if (unity_OrthoParams.w > 0.5)
                {
                    float dist01;

                    #if UNITY_REVERSED_Z
                        dist01 = 1.0 - rawDepth;
                    #else
                        dist01 = rawDepth;
                    #endif
                    
                    linearEyeDepth = lerp(_ProjectionParams.y, _ProjectionParams.z, dist01);
                }
                // 透视投影处理 (Perspective)
                else
                {
                    linearEyeDepth = LinearEyeDepth(rawDepth, _ZBufferParams);
                }

                return linearEyeDepth;
            }
            
            float CalculateDepthRim(float2 ScreenPos, float3 NormalVS, float RimWidth)
            {
                float2 screenPos = ScreenPos;
                float2 screenPos_bias = ScreenPos + NormalVS.xy * RimWidth * 0.001;
                float depthTex = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,screenPos);
                float depthTex_bias = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,screenPos_bias);
                float depth = GetLinearEyeDepth(depthTex_bias);
                float depth0 = GetLinearEyeDepth(depthTex);
                float rim = saturate((depth - depth0));
                
                return rim;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                
                // 参数准备
                //=============================================================================
                float2 albedoUV = i.uv*_MainTex_ST.xy+_MainTex_ST.zw;
                half4 albedo = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,albedoUV);
                
                #ifdef _ALBEDO_MODE
                return albedo;
                #endif
                
                
                //R: Specular Mask  //G:AO  //B:Specular Intensity  //A:Material Type
                half4 lightMap = SAMPLE_TEXTURE2D(_LightMap,sampler_LightMap,i.uv);
                
                float3 positionWS = TransformObjectToWorld(i.positionOS);
                float4 shadowcoord = TransformWorldToShadowCoord(positionWS);
                float2 screenPos = i.screenPos.xy / i.screenPos.w;
                
                Light mainLight = GetMainLight(shadowcoord);
                float3 mainLightDirectionOS = TransformWorldToObjectDir(mainLight.direction);
                float3 mainLightDirectionWS = mainLight.direction;
                
                float3 normalWS = NormalizeNormalPerPixel(i.normalWS);
                float3 normalVS = mul(UNITY_MATRIX_V,normalWS);
                float3 viewDirWS = normalize(_WorldSpaceCameraPos.xyz - positionWS);
                float3 halfDirWS = normalize(mainLight.direction+viewDirWS);
                
                
                float nDotl = dot(normalWS,mainLightDirectionWS);
                float nDoth = dot(normalWS,halfDirWS);
                float nDotv = dot(normalWS,viewDirWS);
                //=============================================================================
                
                //AO
                //=============================================================================
                float ao = saturate(lightMap.g*2.0);
                #ifdef _FACE_MODE
                float2 faceShaodwMask = SAMPLE_TEXTURE2D(_FaceShadowMap,sampler_FaceShadowMap,i.uv).ra;
                float faceSDF = step(lightMap.g,mainLightDirectionOS.z)*step(0,mainLightDirectionOS.x)+step(1-lightMap.g,mainLightDirectionOS.z)*step(mainLightDirectionOS.x,0);
                faceSDF = saturate(faceSDF);
                ao= lerp(lerp(1.0,faceSDF,faceShaodwMask.x),1.0,faceShaodwMask.y);
                lightMap = 0;
                #endif
                ao = lerp(_AOIntensity,1.0,ao);
                //=============================================================================
                
                
                // Diffuse
                //=============================================================================
                float halflambert = nDotl * 0.5 + 0.5;
                
                float shadowRampValue = smoothstep(0,1-_ShadowRampBias,halflambert);
                
                float lightMap_A_Fixed = pow(lightMap.a,0.45);
                float shadowRampMask1 = step(0.9,lightMap_A_Fixed); // 皮肤 头发
                float shadowRampMask2 = step(0.7,lightMap_A_Fixed) - shadowRampMask1; // 丝绸 丝袜
                float shadowRampMask3 = step(0.5,lightMap_A_Fixed) - shadowRampMask2 - shadowRampMask1; // 金属
                float shadowRampMask4 = step(0.3,lightMap_A_Fixed) - shadowRampMask3 - shadowRampMask2 - shadowRampMask1; //偏软质物体
                float shadowRampMask5 = 1 - shadowRampMask4 - shadowRampMask3 - shadowRampMask2 -shadowRampMask1; //偏硬质物体
                float isDay = step(0,mainLight.direction.y);
                half3 rampColor1 = SAMPLE_TEXTURE2D(_ShadowRampMap,sampler_ShadowRampMap,float2(shadowRampValue,0.05+isDay*0.5)).rgb*shadowRampMask1;
                half3 rampColor2 = SAMPLE_TEXTURE2D(_ShadowRampMap,sampler_ShadowRampMap,float2(shadowRampValue,0.15+isDay*0.5)).rgb*shadowRampMask2;
                half3 rampColor3 = SAMPLE_TEXTURE2D(_ShadowRampMap,sampler_ShadowRampMap,float2(shadowRampValue,0.25+isDay*0.5)).rgb*shadowRampMask3;
                half3 rampColor4 = SAMPLE_TEXTURE2D(_ShadowRampMap,sampler_ShadowRampMap,float2(shadowRampValue,0.35+isDay*0.5)).rgb*shadowRampMask4;
                half3 rampColor5 = SAMPLE_TEXTURE2D(_ShadowRampMap,sampler_ShadowRampMap,float2(shadowRampValue,0.45+isDay*0.5)).rgb*shadowRampMask5;
                half3 rampColor = rampColor1+rampColor2+rampColor3+rampColor4+rampColor5;
                
                half3 diffuse = rampColor*albedo.rgb*mainLight.color;
                //=============================================================================
                
                
                // Specular
                //=============================================================================
                float blinnPhong = pow(max(0,nDoth),_SpecularPow+0.001);
                float2 metalMapUV = normalVS.xy*0.5 + 0.5;
                half3 metalMap = SAMPLE_TEXTURE2D(_MetalMap,sampler_MetalMap,metalMapUV);
                half3 metallic = metalMap*_SpecularInt_Metallic*lightMap.b;
                float metallicRange = step(0.9,lightMap.r);
                half3 nonMetallic = step(lightMap.r,blinnPhong) *lightMap.b*_SpecularInt;
                half3 specular =  lerp(nonMetallic,metallic,metallicRange)*albedo.rgb;
                //=============================================================================
                
                
                // Rim
                //=============================================================================
                float depthRim = CalculateDepthRim(screenPos,normalVS,_RimWidth);
                float fresnelRim = pow(1-max(0,nDotv),_FresnelPow+0.001);
                half3 rim = fresnelRim*depthRim*_RimCol*_RimInt*albedo.rgb;
                //=============================================================================
                
                
                // Emission
                //=============================================================================
                half3 emission = 0;
                #ifdef _FACE_MODE
                emission = albedo.a*_EmissionTint.rgb*_EmissionInt;
                #else
                emission = albedo.a*albedo.rgb*_EmissionTint.rgb*_EmissionInt;
                #endif
                
                
                // Result
                //=============================================================================
                half3 finalRGB = (diffuse+specular)*ao+rim+emission;
                //=============================================================================
                
                return float4(finalRGB,1.0);
                
            }
            
            ENDHLSL
        }

        //Outline
        pass
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            Cull Front
            Lighting Off
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
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
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;

                // 1. 先计算原始顶点的裁剪空间坐标 (不带任何偏移)
                float4 clipPos = TransformObjectToHClip(v.vertex.xyz);

                // 2. 计算法线在裁剪空间的方向
                // 技巧：变换“顶点+法线”的位置，减去“顶点”的位置，就得到了这一点的法线方向
                // 这一步是为了保证法线方向也是经过透视变换的，方向才正确
                float4 clipNormal = TransformObjectToHClip(v.vertex.xyz + v.normal) - clipPos;

                // 3. 归一化屏幕二维方向 (只取 xy)
                float2 offset = normalize(clipNormal.xy);

                // 4. 获取屏幕参数并计算长宽比
                float4 scaledScreenParams = GetScaledScreenParams();
                float aspect = abs(scaledScreenParams.x / scaledScreenParams.y);
                
                // 5. 获取线性距离 (单位通常是米)
                float distanceToCamera = clipPos.w; 

                // 6. 计算淡出系数 (0到1之间)
                // 逻辑：如果距离小于 (Max - Range)，系数为1 (满宽度)
                //       如果距离等于 Max，系数为0 (无宽度)
                float maxDistance = 50;
                float fadeRange = 20;
                float distanceFactor = saturate((maxDistance - distanceToCamera) / fadeRange);

                // 7. 应用距离剔除
                float dynamicWidth = _OutlineWidth * distanceFactor;

                // 8. 修正长宽比
                // 如果不除以长宽比，在宽屏上描边会在 X 轴方向显得更粗
                offset.x /= aspect;

                // 9. 应用偏移 (核心步骤)
                // * clipPos.w : 抵消透视除法，实现“近大远小”的反向补偿，达成由远及近视觉一致
                // * 0.01     : 因为裁剪空间是 -1 到 1，单位很小，这里加个系数方便 _OutlineWidth 调节
                clipPos.xy += offset * dynamicWidth * clipPos.w * 0.01;

                o.pos = clipPos;
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                return _OutlineColor;
            }
            
            ENDHLSL
        }
    }
}