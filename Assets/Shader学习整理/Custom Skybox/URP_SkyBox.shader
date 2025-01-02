Shader "URP/SkyBox"
{
    Properties
    {
        [Header(Sun And Moon)]
        _SunRadius("Sun Radius",Range(0,0.5)) = 0.2
        _SunOuterBoundary("Sun Outer Boundary",Range(0,1)) = 1
        [HDR]_SunColor("Sun Color", color) = (1,1,1,1) 
        
        _MoonTex("Moon Texture",2D) = "white"{}
        _MoonRadius("Moon Radius",Range(0,0.5)) = 0.2
        _MoonOffset("Moon Offset",Range(-1,1)) = 0
        _MoonOuterBoundary("MoonOuterBoundary",Range(0,1)) = 1
        [HDR]_MoonColor("Moon Color", color) = (1,1,1,1) 
        
        [Header(Day And Night)]
        _DayTopColor("Day Top Color",Color) = (1,1,1,1)
        _DayBottomColor("Day Bottom Color",Color) = (0,0,0,1)
        _NightTopColor("Night Top Color",Color) = (0.5,0.5,0.5,1)
        _NightBottomColor("Night Bottom Color",Color) = (0,0,0,1)
        
        [Header(Star)]
        [HDR]_StarColor("Star Color",color) = (1,1,1,1)
        _StarTex("Star Tex",2D) = "black"{}
        _StarNoiseTex("Star Noise Tex",3D) = "white"{}
        _StarTwinkleSpeed("Star Twinkle Speed",Range(0,1)) = 1
        _StarNum("Star Num",Range(0,5)) = 1
        
        [Header(Horizon)]
        _HorizonWidth("Horizon Width",Range(0,1)) = 1
        _HorizonGradientRange("Horizon Gradient Range",Range(0,0.5)) = 0.2
        _HorizonDayColor("Horizon Day Color",color) = (1,1,1,1)
        _HorizonNightColor("Horizon Night Color",color) = (0.6,0.6,0.6,1)
        _OffsetHorizon("Offset Horizon", Range(-1,1)) = 0
        _HorizonIntensity("Horizon Intensity",Range(0,2)) = 1
    }
    
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "RenderPipeline" = "UniversalPipeline"  
        }
        
        ZWrite Off
        Cull Off

        //解决深度引动模式Depth Priming Mode问题
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/DepthNormals"
        
        pass
        {
            //Tags{"LightMode"="UniversalForward"}
            Tags { "QUEUE"="Background" "RenderType"="Background" "PreviewType"="Skybox" }
             
            HLSLPROGRAM
            

            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MoonTex);//定义贴图
            SAMPLER(sampler_MoonTex);//定义采样器
            TEXTURE2D(_StarTex);//定义贴图
            SAMPLER(sampler_StarTex);//定义采样器
            TEXTURE3D(_StarNoiseTex);//定义贴图
            SAMPLER(sampler_StarNoiseTex);//定义采样器
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------

            float4x4 _SunTransformMatrix;
            float _SunOuterBoundary;
            float _SunRadius;
            float _MoonOuterBoundary;
            float _MoonRadius;
            float _MoonOffset;
            half4 _SunColor;
            half4 _MoonColor;
            float4 _MoonTex_ST;

            half4 _StarColor;
            float _StarNum;
            float _StarTwinkleSpeed;
            float4 _StarTex_ST;
            float4 _StarNoiseTex_ST;

            half4 _DayTopColor;
            half4 _DayBottomColor;
            half4 _NightTopColor;
            half4 _NightBottomColor;

            float _HorizonWidth;
            float _HorizonGradientRange;
            half4 _HorizonDayColor;
            half4 _HorizonNightColor;
            float _OffsetHorizon;
            float _HorizonIntensity;
            //----------变量声明结束-----------
            CBUFFER_END

            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float3 uv : TEXCOORD0;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float3 uv : TEXCOORD0;
                float3 nDirWS : TEXCOORD1;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                return o;
            }
            
            half4 frag (vertexOutput i) : SV_TARGET
            {
                //Sun
                float sun = distance(_MainLightPosition.xyz,i.uv.xyz);
                float sunArea = 1 - saturate(sun / _SunRadius);
                sunArea = smoothstep(0,_SunOuterBoundary,sunArea);
                half3 sunCol = sunArea*_SunColor;

                //Moon
                float moon = distance(-_MainLightPosition,i.uv.xyz);
                float crescentMoon = distance( -_MainLightPosition,float3(i.uv.x+_MoonOffset,i.uv.yz));
                float moonArea = 1 - saturate(moon / _MoonRadius);
                moonArea  = smoothstep(0,_MoonOuterBoundary,moonArea);
                float crescentMoonArea = 1 - saturate(crescentMoon / (_MoonRadius*0.95));
                crescentMoonArea = saturate(crescentMoonArea*50);
                moonArea = saturate(moonArea-crescentMoonArea);
                float3 moonUV_Raw = mul(i.uv.xyz,_SunTransformMatrix);
                float2 moonUV = moonUV_Raw.xy*_MoonTex_ST.xy + _MoonTex_ST.zw;
                half3 moonTex = SAMPLE_TEXTURE2D(_MoonTex, sampler_MoonTex,moonUV).rgb;
                half3 moonCol = lerp(moonTex.rgb,_MoonColor,moonTex.x)*moonArea;
                
                //Star
                float4 starTex = SAMPLE_TEXTURE2D(_StarTex,sampler_StarTex,frac(i.uv.xz*_StarTex_ST.xy + _StarTex_ST.zw));
                float4 starNoiseTex = SAMPLE_TEXTURE3D(_StarNoiseTex,sampler_StarNoiseTex,frac(i.uv.xyz*_StarNoiseTex_ST.x + _Time.x*0.12*_StarTwinkleSpeed));
                float starPos = smoothstep(0.21,0.31,starTex.r*_StarNum);
                float starBright = smoothstep(0.5,0.7,starNoiseTex.r);
                float star = starPos*starBright;
                float sunNightStep = smoothstep(-0.3,0.25,_MainLightPosition.y);
                float starMask = lerp((1 - smoothstep(-0.7,-0.2,-i.uv.y)),0,sunNightStep);
                half3 starFinalColor = star*_StarColor.rgb*starMask;

                //Day Night
                half3 gradientDay = lerp(_DayBottomColor, _DayTopColor, saturate(i.uv.y));
                half3 gradientNight = lerp(_NightBottomColor, _NightTopColor, saturate(i.uv.y));
                half3 dayCol = gradientDay;
                half3 nightCol = gradientNight+starFinalColor;

                half3 skyGradients = lerp(nightCol, dayCol,saturate(_MainLightPosition.y));

                //Horizon
                float horizon = 1-saturate(abs(i.uv.y - _OffsetHorizon));
                horizon = smoothstep(1-_HorizonWidth,1-_HorizonWidth+_HorizonGradientRange,horizon)* _HorizonIntensity;
                half3 horizonColor = horizon*lerp(_HorizonNightColor, _HorizonDayColor,saturate(_MainLightPosition.y));
            	
                float skyArea = 1-moonArea-sunArea-horizon;

                half3 FinalRGB = sunCol+moonCol+skyGradients*skyArea+horizonColor;
                half4 result = half4(FinalRGB,1.0);
                return result;
            }
            
            ENDHLSL
        }
    }
}