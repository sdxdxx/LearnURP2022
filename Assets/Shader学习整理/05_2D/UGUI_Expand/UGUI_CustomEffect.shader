Shader "URP/2D/UGUI/CustomEffect"
{
    Properties
    {
        [HideInInspector]_MainTex ("Sprite Texture", 2D) = "white" {}
        
        [HideInInspector][Toggle(_IsText)]_IsText("Is Text",float) = 0.0
        
        [HideInInspector][Toggle(_EnableGradient)]_EnableGradient("Enable Gradient",float) = 0.0
        [HideInInspector][Toggle(_EnableVertexColorMode)]_EnableVertexColorMode("Enable Vertex Color Mode",float) = 0.0
        [HideInInspector]_GradientColor1("Gradient Color 1",Color) = (1,0,0,1)
        [HideInInspector]_GradientColor2("Gradient Color 2",Color) = (0,1,0,1)
        [HideInInspector]_GradientRange("Gradient Range",Range(0,1)) = 0.5
        [HideInInspector]_GradientSmoothRange("Gradient Smooth Range",Range(0,1)) = 0.1
        [HideInInspector]_GradientRotation("_GradientRotation",Range(0,1)) = 1.0
        [HideInInspector]_GradientIntensity("_GradientIntensity",Range(0,1)) = 1.0
        
        [HideInInspector][Toggle(_EnableOutline)]_EnableOutline("Enable Outline",float) = 0.0
        [HideInInspector][HDR]_OutlineColor("Outline Color",Color) = (0,0,0,1)
        [HideInInspector]_OutlineWidth("Outline Width",Range(0,10)) = 1
        
        [HideInInspector][Toggle(_EnableShadow)]_EnableShadow("Enable Shadow",float) = 0.0
        [HideInInspector]_ShadowOffset("ShadowOffset:XY",Vector) = (1,1,0,0)
        [HideInInspector]_ShadowScale("Shadow Scale",Range(0.8,1.2)) = 1
        [HideInInspector]_ShadowColor("Shadow Color",Color) = (0,0,0,1)

        // Legacy properties. They're here so that materials using this shader can gracefully fallback to the legacy sprite shader.
        [HideInInspector] _Color ("Tint", Color) = (1,1,1,1)
        [HideInInspector] PixelSnap ("Pixel snap", Float) = 0
        [HideInInspector] _RendererColor ("RendererColor", Color) = (1,1,1,1)
        [HideInInspector] _Flip ("Flip", Vector) = (1,1,1,1)
        [HideInInspector] _AlphaTex ("External Alpha", 2D) = "white" {}
        [HideInInspector] _EnableExternalAlpha ("Enable External Alpha", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }

        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off
        ZWrite Off

		HLSLINCLUDE
		
		    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		    
		    #pragma shader_feature _IsText
            #pragma shader_feature _EnableVertexColorMode
            #pragma shader_feature _EnableGradient
            #pragma shader_feature _EnableOutline
            #pragma shader_feature _EnableUnderline
            #pragma shader_feature _EnableShadow

 			float2x2 AngleRotateMatrix(float Angle, float2 Center)
            {
                float angle = 1-Angle;
                float rotateCos = cos(angle*2*PI);
                float rotateSin = sin(angle*2*PI);
                float2 UVCenter = Center;
                float2x2 rotate = float2x2(rotateCos,-rotateSin,rotateSin,rotateCos);
                return rotate;
            }

             float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
             {
               return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
             }
		
		    
            struct Attributes
            {
                float3 positionOS   : POSITION;
                float4 color        : COLOR;
                float4 uv           : TEXCOORD0;
		        float4 uv1 : TEXCOORD1;
                float4 uv2 : TEXCOORD2;
            };

            struct Varyings
            {
                float4  positionCS  : SV_POSITION;
                half4   color       : COLOR;
                float4  uv          : TEXCOORD0;
                float4 original_uv_MinAndMax : TEXCOORD1;
                float3  positionOS  : TEXCOORD2;
                float4 uv2 : TEXCOORD3;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float4 _MainTex_ST;
            float4 _MainTex_TexelSize;

            half4 _GradientColor1;
            half4 _GradientColor2;
            float _GradientRange;
            float _GradientSmoothRange;
            float _GradientRotation;
            float _GradientIntensity;
            
            half4 _OutlineColor;
            float _OutlineWidth;
            
            float4 _VertexMinAndMax;
            float _UnderlineWidth;

            float2 _ShadowOffset;
            half4 _ShadowColor;
            float _ShadowScale;

            half4 _UnderlineColor;
            float4 _Color;
            half4 _RendererColor;

		    half IsInRect(float2 uv, float4 originalUV)
            {
                uv = step(originalUV.xy, uv)* step(uv, originalUV.zw);
                return uv.x * uv.y;
            }

            half SampleAlpha(int index, float2 uv, float4 originalUV)
            {
                //圆的12个方向数组
                const half sinArray[12] = { 0, 0.5, 0.866, 1, 0.866, 0.5, 0, -0.5, -0.866, -1, -0.866, -0.5 };
                const half cosArray[12] = { 1, 0.866, 0.5, 0, -0.5, -0.866, -1, -0.866, -0.5, 0, 0.5, 0.866 };

                //uv偏移
                float2 uv_new = uv + _MainTex_TexelSize.xy * float2(cosArray[index], sinArray[index]) * _OutlineWidth;
                
                half result = IsInRect(uv_new, originalUV) * SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv_new).a * _OutlineColor.a;
				return result;
            }
            
            half4 Outline(half4 color, half4 outlineColor, float width, float2 uv, float4 originalUV)
            {
                //将偏移的12个方向的图片的范围合成，减去原Alpha值得到外描边的遮罩
                float outlineRange = 0;
                for (int i =0; i<12; i++)
                {
                    outlineRange += SampleAlpha(i,uv,originalUV);
                }
                outlineRange = (saturate(outlineRange)-color.a)*step(0.00001f,width);
                
                //让描边变色
                 half4 result = lerp(color,_OutlineColor,outlineRange);
                
                //遮罩加上原Alpha值
                 result.a = color.a+outlineRange;
                return result;
            }

		    Varyings ShadowVertex(Attributes v)
            {
                Varyings o = (Varyings)0;
		        float2x2 scaleMatrix = float2x2(
                    _ShadowScale,0,
                    0,_ShadowScale);
                v.positionOS.xy = mul(scaleMatrix,v.positionOS.xy);
                v.positionOS.xy +=_ShadowOffset;
                o.positionCS = TransformObjectToHClip(v.positionOS);
                o.positionOS = v.positionOS;
                o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
		        o.uv.zw = v.uv.zw;
                o.color = v.color * _Color * _RendererColor;
		        o.original_uv_MinAndMax = v.uv1;
		        o.uv2 = v.uv2;
                return o;
            }

		    Varyings UnlitVertex(Attributes v)
            {
                Varyings o = (Varyings)0;
                o.positionCS = TransformObjectToHClip(v.positionOS);
                o.positionOS = v.positionOS;
                o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
		        o.uv.zw = v.uv.zw;
                o.color = v.color * _Color * _RendererColor;
		        o.original_uv_MinAndMax = v.uv1;
		        o.uv2 = v.uv2;
                return o;
            }
		    
		     half4 ShadowFragment(Varyings i) : SV_Target
            {
                #ifdef _EnableShadow
                 //剔除原UV之外内容
                float2 shadowUV = i.uv.xy;
                float4 shadowOriginalUV = i.original_uv_MinAndMax;
                float mainTex_shadow = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,shadowUV).a;
                float shadowLimitation = IsInRect(shadowUV,shadowOriginalUV);
                mainTex_shadow *= shadowLimitation;
                half4 shadow = half4(_ShadowColor.rgb,mainTex_shadow);
                return shadow;
                #else
                discard;
                return 0;
                #endif
            }

            half4 UnlitFragment(Varyings i) : SV_Target
            {
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv.xy)*IsInRect(i.uv.xy,i.original_uv_MinAndMax);
                mainTex.rgb *= i.color.rgb;
                
                #ifdef _IsText
                mainTex.rgb = i.color.rgb;
                #endif
                
                #ifdef _EnableGradient
                    #ifdef _EnableVertexColorMode
                        #ifdef _IsText
                        half3 gradient = i.color.rgb;
                        mainTex.rgb = gradient;
                        #endif
                
                        
                    #else

                        #ifdef _IsText
                            //正常文字Gradient模式
                            float4 vertexMinAndMax = _VertexMinAndMax;
                            float centerX_OS = (vertexMinAndMax.x+vertexMinAndMax.z)/2;
                            float centerY_OS = (vertexMinAndMax.y+vertexMinAndMax.w)/2;
                            float width = vertexMinAndMax.z - vertexMinAndMax.x;
                            float height = vertexMinAndMax.w - vertexMinAndMax.y; 
                            float2 center_OS = float2(centerX_OS,centerY_OS);
                            float2x2 graidentRotationMatrix = AngleRotateMatrix(_GradientRotation,center_OS);
                            float2 gradientOS = mul(graidentRotationMatrix,i.positionOS-center_OS)+center_OS;
                            float gradientRange = (_GradientRange*2-1)*width;
                            float gradientSmoothRange = _GradientSmoothRange*width;
                            float gradientMask = smoothstep(gradientRange,gradientRange+gradientSmoothRange,gradientOS.x);
                            half3 gradient = lerp(_GradientColor1.rgb,_GradientColor2.rgb,gradientMask);
                            mainTex.rgb = gradient;
                        #else
                            //正常图片Gradient模式
                            float2 uvCenter = float2(0.5,0.5);
                            float2x2 graidentRotationMatrix = AngleRotateMatrix(_GradientRotation,uvCenter);
                            float2 gradientUV = mul(graidentRotationMatrix,i.uv-uvCenter)+uvCenter;
                            float gradientMask = smoothstep(_GradientRange,_GradientRange+_GradientSmoothRange,gradientUV);
                            half3 gradient = mainTex.rgb * lerp(_GradientColor1.rgb,_GradientColor2.rgb,gradientMask);
                            mainTex.rgb = lerp(mainTex.rgb,gradient,_GradientIntensity);
                        #endif
                       
                    
                    #endif
                
                #endif
                
                
                half4 result = mainTex;
                float outlineWidth = 0;
                
                #ifdef _EnableOutline
                //剔除原UV之外内容
                outlineWidth = _OutlineWidth+0.0001f;
                #endif
                
                result = Outline(mainTex,_OutlineColor,outlineWidth,i.uv.xy,i.original_uv_MinAndMax);

                
                float underLineMask = step(5.0,i.uv.z);
                result.a = max(underLineMask,result.a)*i.color.a;
                result.rgb = lerp(result.rgb,_UnderlineColor.rgb,underLineMask);
                
                
                return result;
            }
		ENDHLSL

        //ShadowPass
        Pass
        {
            Tags { "LightMode" = "SRPDefaultUnlit" }
            
            HLSLPROGRAM
            
			#pragma vertex ShadowVertex
            #pragma fragment ShadowFragment
			
            ENDHLSL
        }

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

    Fallback "Sprites/Default"
}
