Shader "URP/VFX/UniversalEffect"
{
    Properties
    {
         //MainTex
        [HideInInspector][HDR]_BaseColor("Color",Color) = (1,1,1,1)
        [HideInInspector][PerRenderData]_MainTex("MainTex", 2D) = "white" {}
        [HideInInspector]_USpeed_MainTex("U Speed", Float) = 0
        [HideInInspector]_VSpeed_MainTex("V Speed", Float) = 0
        [HideInInspector][Toggle(_EnableMainTexRotation)] _EnableMainTexRotation("Enable MainTex Rotation",Float)= 0
        [HideInInspector]_MainTexRotation("MainTex Rotation",Range(0,1)) = 0
        
        //MainTex Polar Coordinates
        [HideInInspector][Toggle(_EnablePolarCoordinates)]_EnablePolarCoordinates("Enable Polar Coordinates", float) = 0
        [HideInInspector]_PolarCoordinatesMovingSpeed("Polar Coordinates Moving Speed", Float) = 0
        
        //Distortion
        [HideInInspector][Toggle(_EnableDistortion)] _EnableDistortion("Enable Distortion",Float)= 0
        [HideInInspector][Toggle(_EnableMainTexDistortion)] _EnableMainTexDistortion("Enable MainTex Distortion",Float)= 0
        [HideInInspector][Toggle(_EnableDissolveMaskDistortion)] _EnableDissolveMaskDistortion("Enable Dissolve Mask Distortion",Float)= 0
        [HideInInspector][Toggle(_EnableDistortionPolarCoordinates)]_EnableDistortionPolarCoordinates("Enable Distortion Polar Coordinates", float) = 0
        [HideInInspector]_DistortionMap("Distortion Map", 2D) = "black" {}
        [HideInInspector]_DistortionIntensity("Distortion Intensity", Range(0, 2)) = 0
        [HideInInspector]_USpeed_Distortion("U Speed", Float) = 0
        [HideInInspector]_VSpeed_Distortion("V Speed", Float) = 0
        [HideInInspector][Toggle(_EnableDistortionMapRotation)] _EnableDistortionMapRotation("Enable Distortion Map Rotation",Float)= 0
        [HideInInspector]_PolarCoordinatesMovingSpeed_Distortion("Polar Coordinates Moving Speed", Float) = 0
        [HideInInspector]_DistortionMapRotation("Distortion Map Rotation",Range(0,1)) = 0
        
        //Mask
        [HideInInspector][Toggle(_EnableMaskR)] _EnableMaskR("Enable Mask Single R",Float)= 0
        [HideInInspector]_Mask("Mask", 2D) = "white" {}
        [HideInInspector][Toggle(_EnableExtraMask)] _EnableExtraMask("Enable Extra Mask",Float)= 0
        [HideInInspector][Toggle(_EnableExtraMaskR)] _EnableExtraMaskR("Enable Extra Mask Single R",Float)= 0
        [HideInInspector]_ExtraMask("Extra Mask", 2D) = "white" {}
        [HideInInspector][Toggle(_EnableMaskRotation)] _EnableMaskRotation("Enable Mask Rotation",Float)= 0
        [HideInInspector][Toggle(_EnableExtraMaskRotation)] _EnableExtraMaskRotation("Enable Extra Mask Rotation",Float)= 0
        [HideInInspector]_MaskRotation("Mask Rotation",Range(0,1)) = 0
        [HideInInspector]_ExtraMaskRotation("Extra Mask Rotation",Range(0,1)) = 0
         
        //遮罩消散
        [HideInInspector][Toggle(_EnableDissolve)] _EnableDissolve("Enable Dissolve",Float)= 0
        [HideInInspector][Toggle(_EnableDissolveMaskPolarCoordinates)] _EnableDissolveMaskPolarCoordinates("Enable Dissolve Mask Polar Coordinates",Float)= 0
        [HideInInspector][Toggle(_EnableDissolveMaskR)] _EnableDissolveMaskR("Enable Dissolve Mask Single R",Float)= 1
        [HideInInspector][Toggle( _EnableDissolveCustomData)]  _EnableDissolveCustomData(" _Enable Dissolve Custom Data",Float)= 0
        
        [HideInInspector]_DissolveMask("Dissolve Mask", 2D) = "white" {}
        [HideInInspector]_DissolveRange("Dissolve Range",Range(0,1)) = 0
        [HideInInspector]_DissolveSmoothness("Dissolve Smoothness",Range(0,1)) = 0
        [HideInInspector]_DissolveWidth("Dissolve Width",Range(0,1)) = 0
        [HideInInspector][HDR]_DissolveEdgeColor("DissolveEdgeColor",Color) = (1,1,1,1)
         
        //Mode
        [HideInInspector][Enum(UnityEngine.Rendering.BlendMode)] _BlendSrc("Blend Src Factor", float) = 5   //SrcAlpha
        [HideInInspector][Enum(UnityEngine.Rendering.BlendMode)] _BlendDst("Blend Dst Factor", float) = 10  //OneMinusSrcAlpha
        [HideInInspector][Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", float) = 2 //Back
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent+500"
            "IgnoreProjector" = "true"
            "RenderType" = "Transparent"
            "PreviewType"="Plane"
            "RenderPipeline" = "UniversalPipeline"
        }

        Lighting Off
        Blend [_BlendSrc] [_BlendDst]
        Cull[_CullMode]
        ZWrite Off

		HLSLINCLUDE
		
		    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		    
		    #pragma shader_feature _EnablePolarCoordinates
            #pragma shader_feature _EnableDistortionPolarCoordinates
		    
            #pragma shader_feature _EnableExtraMask
            #pragma shader_feature _EnableMaskR
            #pragma shader_feature _EnableExtraMaskR
            #pragma shader_feature _EnableMaskRotation
            #pragma shader_feature _EnableExtraMaskRotation
            
            #pragma shader_feature _EnableDistortion
            #pragma shader_feature _EnableDissolve
            #pragma shader_feature _EnableDissolveMaskPolarCoordinates
            #pragma shader_feature _EnableMainTexDistortion
            #pragma shader_feature _EnableDissolveMaskDistortion
            #pragma shader_feature _EnableDissolveMaskR
            #pragma shader_feature _EnableDissolveCustomData
            
            #pragma shader_feature _EnableMainTexRotation
            #pragma shader_feature _EnableDistortionMapRotation

 			float2x2 AngleRotateMatrix(float Angle)
            {
                float angle = 1-Angle;
                float rotateCos = cos(angle*2*PI);
                float rotateSin = sin(angle*2*PI);
                float2x2 rotate = float2x2(rotateCos,-rotateSin,rotateSin,rotateCos);
                return rotate;
            }

             float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
             {
               return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
             }

		    float2 UVFlow(float2 uv, float2 uvSpeed)
            {
                float time = _Time.z;
                uv += uvSpeed*time;
                return uv;
            }

            float2 TransformToPolarCordinate(float2 originUV, float speed, float2 uvBias)
            {
                float2 uv = originUV - float2(0.5,0.5);          //原点中心位置 右上挪到中间。
                float theta = atan2(uv.y,uv.x);                  //笛卡尔坐标  换算成  极坐标.
                theta = theta / 3.1415926  * 0.5 +0.5;           //remap纠正 值域 -1 到 1  为 正值 0 到 1：
                float r = length(uv) + _Time.z * speed+uvBias.x + uvBias.y;    //距离中心点，任意一点 的长度。然后+上计时器 * Speed 的速度。
                //float r = frac(length(uv) + _Time.z * speed+uvBias.x + uvBias.y); 
                uv = float2(theta,r);                            //获取 角度 和 长度 后，传递给 i.uv;
                return uv;
            }
		
		    
            struct Attributes
            {
                float4 vertex : POSITION;
                float4 color : COLOR;
                float4 uv : TEXCOORD0;
                float4 uv1 : TEXCOORD1;
            };

            struct Varyings
            {
                float4 uv : TEXCOORD0;
                float4 uv1 : TEXCOORD1;
                float3 posOS : TEXCOORD2;
                float4 color : COLOR;
                float4 vertex : SV_POSITION;
            };

		    //----------贴图声明开始-----------
            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
		    TEXTURE2D(_Mask); SAMPLER(sampler_Mask);
		    TEXTURE2D(_ExtraMask); SAMPLER(sampler_ExtraMask);
		    TEXTURE2D(_DistortionMap); SAMPLER(sampler_DistortionMap);
		    TEXTURE2D(_DissolveMask;); SAMPLER(sampler_DissolveMask;);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            float4 _Mask_ST;
            float4 _ExtraMask_ST;

            half4 _BaseColor;
            float4 _MainTex_ST;
            float _CustomTime;
            float4 _DistortionMap_ST;
            half _DistortionIntensity;
            float _USpeed_MainTex;
            float _VSpeed_MainTex;
            float _USpeed_Distortion;
            float _VSpeed_Distortion;
            
            float _MainTexRotation;
            float _DistortionMapRotation;
		    float _MaskRotation;
		    float _ExtraMaskRotation;
		    
            float4 _DissolveMask_ST;
            float _DissolveRange;
            float _DissolveSmoothness;
            float _DissolveWidth;
            half4 _DissolveEdgeColor;

            float _PolarCoordinatesMovingSpeed;
            float _PolarCoordinatesMovingSpeed_Distortion;
            //----------变量声明结束-----------
            CBUFFER_END
		    
		    
		    Varyings UnlitVertex(Attributes v)
            {
                Varyings o = (Varyings)0;
                float4 posCS = TransformObjectToHClip(v.vertex);
                o.vertex = posCS;
                o.uv = v.uv;
                o.uv1 = v.uv1;
                o.color = v.color;
                o.posOS = v.vertex;
                return o;
            }

            half4 UnlitFragment(Varyings i) : SV_Target
            {
                //UV计算
                
                //UV流动
                float2 mainTexUV = i.uv.xy*_MainTex_ST.xy;
                 #ifdef _EnableMainTexRotation
                        float2 UVCenter_MainTex = float2(0.5,0.5)*_MainTex_ST.xy;
                        float2x2 rotateMatrix_MainTex = AngleRotateMatrix(_MainTexRotation);
                        mainTexUV = mul(mainTexUV-UVCenter_MainTex,rotateMatrix_MainTex)+UVCenter_MainTex;
                #endif
                #ifdef _EnablePolarCoordinates
                    mainTexUV = TransformToPolarCordinate(mainTexUV,_PolarCoordinatesMovingSpeed,_MainTex_ST.zw);
                #else
                    mainTexUV += _MainTex_ST.zw;
                    mainTexUV = UVFlow(mainTexUV, float2(_USpeed_MainTex, _VSpeed_MainTex));
                #endif

                
               

                //UV扰动
                float2 distortion = 0;
                #ifdef _EnableDistortion
                    float2 distortionMapUV = i.uv.xy*_DistortionMap_ST.xy;
                     #ifdef _EnableDistortionMapRotation
                        float2 UVCenter_DistortionMap = float2(0.5,0.5)*_DistortionMap_ST.xy;
                        float2x2 rotateMatrix_DistortionMap = AngleRotateMatrix(_DistortionMapRotation);
                        distortionMapUV = mul(distortionMapUV-UVCenter_DistortionMap,rotateMatrix_DistortionMap)+UVCenter_DistortionMap;
                    #endif
                    #ifdef _EnableDistortionPolarCoordinates
                        distortionMapUV = TransformToPolarCordinate(distortionMapUV,_PolarCoordinatesMovingSpeed_Distortion,_DistortionMap_ST.zw);
                    #else
                        distortionMapUV+= _DistortionMap_ST.zw;
                        distortionMapUV = UVFlow(distortionMapUV, float2(_USpeed_Distortion, _VSpeed_Distortion));
                    #endif
                    distortion = SAMPLE_TEXTURE2D(_DistortionMap, sampler_DistortionMap, distortionMapUV).rg * _DistortionIntensity;
                #endif

                //MainTex
                #ifdef _EnableMainTexDistortion
                        mainTexUV = mainTexUV + distortion;
                #endif
                half4 mainTex = i.color * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,mainTexUV)*_BaseColor;

                //Mask
                float2 maskUV = i.uv.xy*_Mask_ST.xy + i.uv.xy*_Mask_ST.zw;
                maskUV = UVFlow(maskUV, float2(_USpeed_MainTex, _VSpeed_MainTex));
                #ifdef _EnableMaskRotation
                        float2 UVCenter_Mask = float2(0.5,0.5)*_Mask_ST.xy+_Mask_ST.zw;
                        float2x2 rotateMatrix_Mask = AngleRotateMatrix(_MaskRotation+_MainTexRotation);
                        maskUV = mul(maskUV-UVCenter_Mask,rotateMatrix_Mask)+UVCenter_Mask;
                #endif
                float4 mask = 0;
                #ifdef _EnableMaskR
                     mask = SAMPLE_TEXTURE2D(_Mask,sampler_Mask,maskUV).r;
                #else
                     mask = SAMPLE_TEXTURE2D(_Mask,sampler_Mask,maskUV);
                #endif
                mainTex *= mask;
                
                #ifdef _EnableExtraMask
                    float2 extraMaskUV = i.uv.xy*_ExtraMask_ST.xy + i.uv.xy*_ExtraMask_ST.zw;
                    extraMaskUV = UVFlow(extraMaskUV, float2(_USpeed_MainTex, _VSpeed_MainTex));
                    #ifdef _EnableExtraMaskRotation
                        float2 UVCenter_ExtraMask = float2(0.5,0.5)*_ExtraMask_ST.xy+_ExtraMask_ST.zw;
                        float2x2 rotateMatrix_ExtraMask = AngleRotateMatrix(_ExtraMaskRotation+_MainTexRotation);
                        extraMaskUV = mul(maskUV-UVCenter_ExtraMask,rotateMatrix_ExtraMask)+UVCenter_ExtraMask;
                    #endif
                    float4 extraMask = 0;
                    #ifdef _EnableExtraMaskR
                        extraMask = SAMPLE_TEXTURE2D(_ExtraMask,sampler_ExtraMask,extraMaskUV).r;
                    #else
                        extraMask = SAMPLE_TEXTURE2D(_ExtraMask,sampler_ExtraMask,extraMaskUV);
                    #endif
                    mainTex *= extraMask;
                #endif
                
                half3 finalRGB = mainTex.rgb;
                
                //溶解
                float finalAlpha = mainTex.a;
                #ifdef _EnableDissolve
                    float2 dissolveMaskUV = i.uv.xy*_DissolveMask_ST.xy;
                     #ifdef _EnableDissolveMaskPolarCoordinates
                        dissolveMaskUV = TransformToPolarCordinate(dissolveMaskUV,_PolarCoordinatesMovingSpeed,_DissolveMask_ST.zw);
                    #else
                        dissolveMaskUV += _DissolveMask_ST.zw;
                     #endif

                    #ifdef _EnableDissolveMaskDistortion
                        dissolveMaskUV +=distortion;
                    #endif
                
                    float4 dissolveMask = SAMPLE_TEXTURE2D(_DissolveMask,sampler_DissolveMask,dissolveMaskUV);
                    float realDissolveMask = dissolveMask;
                    #ifdef _EnableDissolveMaskR
                        realDissolveMask = dissolveMask.rrrr;
                    #endif
                
                    float dissolveSmoothness = max(0.00001,_DissolveSmoothness);
                    float dissolveRange = 0;
                    #ifdef _EnableDissolveCustomData
                        float4 customData = i.uv1;
                        dissolveRange = saturate(customData.x)*(1.0+dissolveSmoothness+_DissolveWidth);
                    #else
                        dissolveRange = _DissolveRange*(1.0+dissolveSmoothness+_DissolveWidth);
                    #endif
                    float dissolve1 = smoothstep(dissolveRange-dissolveSmoothness,dissolveRange,dissolveMask);
                    dissolveRange -= _DissolveWidth;
                    float dissolve2 = smoothstep(dissolveRange-dissolveSmoothness,dissolveRange,dissolveMask);
                    finalRGB = lerp(_DissolveEdgeColor*finalRGB,finalRGB,dissolve1);
                    finalAlpha = dissolve2*finalAlpha;
                #endif
                
                half4 result = half4(finalRGB,finalAlpha);
                return result;

            }
		ENDHLSL
        

        Pass
        {
            Tags { "LightMode" = "Universal2D" }
            
            HLSLPROGRAM
            
			#pragma vertex UnlitVertex
            #pragma fragment UnlitFragment
			
            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "UniversalForward" "Queue"="Transparent" "RenderType"="Transparent"}

            HLSLPROGRAM
            
            #pragma vertex UnlitVertex
            #pragma fragment UnlitFragment
            
            ENDHLSL
        }
    }
    CustomEditor "UniversalEffectGUI"
}
