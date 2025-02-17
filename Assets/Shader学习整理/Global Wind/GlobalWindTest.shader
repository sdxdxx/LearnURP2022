Shader "URP/Test/GlobalWind"
{
    Properties
    {
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _MainTex("MainTex",2D) = "white"{}
        _WindDistortionMap("Wind Distortion Map",2D) = "black"{}
        _WindStrength("_WindStrength",float) = 0
        _U_Speed("U_Seed",float) = 0
        _V_Speed("V_Seed",float) = 0
    }
    
    SubShader
    {
         Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }
    	
    	//解决深度引动模式Depth Priming Mode问题
        //UsePass "Universal Render Pipeline/Unlit/DepthOnly"
        //UsePass "Universal Render Pipeline/Lit/DepthNormals"

         pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);//定义贴图
            SAMPLER(sampler_MainTex);//定义采样器
            TEXTURE2D(_WindDistortionMap);
            SAMPLER(sampler_WindDistortionMap);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float4 _MainTex_ST;
            float4 _WindDistortionMap_ST;
            float _WindStrength;
            float _U_Speed;
            float _V_Speed;
            //----------变量声明结束-----------
            CBUFFER_END

            //AngleAxis3x3()接收一个角度（弧度制）并返回一个围绕提供轴旋转的矩阵
            float3x3 AngleAxis3x3(float angle, float3 axis)
            {
              float c, s;
              sincos(angle, s, c);

              float t = 1 - c;
              float x = axis.x;
              float y = axis.y;
              float z = axis.z;

              return float3x3(
	             t * x * x + c, t * x * y - s * z, t * x * z + s * y,
	             t * x * y + s * z, t * y * y + c, t * y * z - s * x,
	             t * x * z - s * y, t * y * z + s * x, t * z * z + c
	             );
            }

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
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                float3 positionWS_0 = TransformObjectToWorld(float3(0,0,0));
                float windStrength = max(0.0001f,_WindStrength);
                float2 windUV = positionWS_0.xz*_WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + float2(_U_Speed,_V_Speed)*_Time.z;
                float2 windSample = (SAMPLE_TEXTURE2D_LOD(_WindDistortionMap,sampler_WindDistortionMap, windUV,0).xy * 2 - 1) * windStrength;
                float3 wind = normalize(float3(windSample.x,0,windSample.y));
	            float3x3 windRotation = AngleAxis3x3(PI * windSample.x, normalize(float3(0,positionWS.y,0)));
                v.vertex.xyz = mul(windRotation,v.vertex.xyz);
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv*_MainTex_ST.xy+_MainTex_ST.zw;
                o.posWS = positionWS;
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                float3 nDir = i.nDirWS;
                float3 lDir = _MainLightPosition.xyz;
                float halfLambert = dot(nDir,lDir)*0.5+0.5;
                float3 positionWS_0 = TransformObjectToWorld(float3(0,0,0));
                float windStrength = max(0.0001f,_WindStrength);
                float2 windUV = positionWS_0.xz*_WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + float2(_U_Speed,_V_Speed)*_Time.z;
                float2 windSample = (SAMPLE_TEXTURE2D_LOD(_WindDistortionMap,sampler_WindDistortionMap, windUV,0).xy * 2 - 1) * windStrength;
                float2 direction = normalize(float2(sin(PI*windSample.x),cos(PI*windSample.x)));
                
                half4 result = half4(direction,1.0,1.0);
                return result*_BaseColor;
            }
            
            ENDHLSL
        }
    }
}