Shader "URP/Cartoon/BillboardGrass"
{
    Properties
    {
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _MainTex("MainTex",2D) = "white"{}
        
        //Wind
        _WindDistortionMap("Wind Distortion Map",2D) = "black"{}
        _WindStrength("WindStrength",float) = 0
        _U_Speed("U_Seed",float) = 0
        _V_Speed("V_Seed",float) = 0
        _Bias("WindBias",Range(-1.0,1.0)) = 0
    }
    
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
        }
    	
    	//解决深度引动模式Depth Priming Mode问题
        UsePass "Universal Render Pipeline/Unlit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/DepthNormals"

        pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            
            Cull Off
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            //开启GPU Instance
            #pragma multi_compile_instancing
            
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);//定义贴图
            SAMPLER(sampler_MainTex);//定义采样器
            TEXTURE2D(_WindDistortionMap);
            SAMPLER(sampler_WindDistortionMap);
            //----------贴图声明结束-----------

            //GPU Instance
            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                UNITY_DEFINE_INSTANCED_PROP(half4, _BaseColor)
                UNITY_DEFINE_INSTANCED_PROP(float4,_MainTex_ST)
                UNITY_DEFINE_INSTANCED_PROP(float, _WindStrength)
                UNITY_DEFINE_INSTANCED_PROP(float, _U_Speed)
                UNITY_DEFINE_INSTANCED_PROP(float, _V_Speed)
                UNITY_DEFINE_INSTANCED_PROP(float4,_WindDistortionMap_ST)
                UNITY_DEFINE_INSTANCED_PROP(float,_Bias)
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

            //SRP Bathcer
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            
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
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 nDirWS : TEXCOORD1;
                float3 posOS : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                
                //Instance变量
                float windStrength = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_WindStrength);
                float2 windDistorationMap_FlowSpeed = float2(UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_U_Speed),UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_V_Speed));
                float4 windDistortionMap_ST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_WindDistortionMap_ST);
                float bias = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_Bias);
                    
                //Billboard
                float3 newForwardDir = -normalize(GetWorldSpaceViewDir(float3(0,0,0)));
                float3 newRightDir = normalize(cross(float3(0,1,0),newForwardDir));
                float3 newUpDir = normalize(cross(newForwardDir,newRightDir));
                v.vertex.xyz =  v.vertex.x * newRightDir + v.vertex.y * newUpDir + v.vertex.z * newForwardDir;
                
                //Wind
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                float3 positionWS_0 = TransformObjectToWorld(float3(0,0,0));
                windStrength = max(0.0001f,windStrength);
                float2 windUV = positionWS_0.xz*windDistortionMap_ST.xy + windDistortionMap_ST.zw + windDistorationMap_FlowSpeed*_Time.z;
                float2 windSample = ((SAMPLE_TEXTURE2D_LOD(_WindDistortionMap,sampler_WindDistortionMap, windUV,0).xy * 2 - 1)+bias) * windStrength;
                float3 wind = normalize(float3(windSample.x,0,windSample.y));
	            float3x3 windRotation = AngleAxis3x3(PI * windSample.x, newForwardDir);
                v.vertex.xyz = mul(windRotation,v.vertex.xyz);
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                float4 mainTex_ST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _MainTex_ST);
                o.uv = v.uv*mainTex_ST.xy+mainTex_ST.zw;
                o.posOS = v.vertex.xyz;
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(i);
                
                //Instance变量
                half3 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
                
                float3 posWS = TransformObjectToWorld(i.posOS);
                float4 mainShadowCoord = TransformWorldToShadowCoord(posWS);
                Light mainLight = GetMainLight(mainShadowCoord);
                float3 nDirWS = i.nDirWS;
                float3 lDirWS = mainLight.direction.xyz;

                float halfLambert = dot(nDirWS,lDirWS)*0.5+0.5;
                half4 albedo = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv);
                
                half3 finalRGB = albedo*baseColor;
                
                half4 result = half4(finalRGB,albedo.a);
                return result;
            }
            
            ENDHLSL
        }
    }
}