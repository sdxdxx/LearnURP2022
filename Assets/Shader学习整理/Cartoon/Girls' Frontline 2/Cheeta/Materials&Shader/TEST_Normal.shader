Shader "URP/TEST_NORMAL"
{
    Properties
    {
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _MainTex("MainTex",2D) = "white"{}
        
        [Header(Outline)]
        _OutlineColor("Outline Color",Color) = (0.0,0.0,0.0,0.0)
        _OutlineWidth("Outline Width",Range(0,5)) = 1
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
        

      pass
        {
            Name "VertexColor"
            Tags { "LightMode" = "UniversalForward" }
            Lighting Off
            Cull Back
            HLSLPROGRAM

            #pragma vertex vertOutline
            #pragma fragment fragOutline
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _OutlineColor;
            float _OutlineWidth;
            //----------变量声明结束-----------
            CBUFFER_END

            struct vertexInputOutline
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            	float4 tangent : TANGENT;
            	float4 color : COLOR;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD2;
                float2 uv3 : TEXCOORD3;
            };

            struct vertexOutputOutline
            {
                float4 pos : SV_POSITION;
            	float4 color : COLOR;
                float3 normalOS : TEXCOORD0;
            };

            vertexOutputOutline vertOutline (vertexInputOutline v)
            {
                vertexOutputOutline o;

            	float3 bTangent = normalize(cross(v.normal,v.tangent)*v.tangent.w);
            	float3 normalTS = float3(v.uv2.xy,v.uv3.x)*2.0-1.0;
            	float3x3 TBN = float3x3(v.tangent.xyz,bTangent,v.normal.xyz);
            	float3 normalOS = normalize(mul(normalTS,TBN));
            	float3 outline_normal = normalOS;//v.color*2.0-1.0;
                //float4 clipPos = TransformObjectToHClip(v.vertex.xyz+outline_normal*0.01*_OutlineWidth*v.color.a);
                float4 clipPos = TransformObjectToHClip(v.vertex.xyz);
                o.pos = clipPos;
            	o.color = float4(outline_normal,v.color.a);
                o.normalOS = v.normal;
                return o;
            }

            half4 fragOutline (vertexOutputOutline i) : SV_TARGET
            {
                float3 normalWS = TransformObjectToWorldNormal(i.normalOS);
                float lambert = saturate(dot(normalWS,_MainLightPosition));
                return lambert;
            }
            
            ENDHLSL
        }

        pass
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            Lighting Off
            Cull Front
            HLSLPROGRAM

            #pragma vertex vertOutline
            #pragma fragment fragOutline
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _OutlineColor;
            float _OutlineWidth;
            //----------变量声明结束-----------
            CBUFFER_END

            struct vertexInputOutline
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            	float4 tangent : TANGENT;
            	float4 color : COLOR;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD2;
                float2 uv3 : TEXCOORD3;
            };

            struct vertexOutputOutline
            {
                float4 pos : SV_POSITION;
            	float4 color : COLOR;
            };

            vertexOutputOutline vertOutline (vertexInputOutline v)
            {
                vertexOutputOutline o;

            	float3 normalTS = float3(v.uv2.xy, v.uv3.x) * 2.0 - 1.0;

                float3 T = normalize(v.tangent.xyz);
                float3 N = normalize(v.normal.xyz);
                float3 B = normalize(cross(N, T) * (v.uv3.y*2.0-1.0));

                float3 normalOS = normalize(normalTS.x * T + normalTS.y * B + normalTS.z * N);
                float3 outline_normal = normalOS;
                //float3 outline_normal = v.color*2.0-1.0;
                
                float4 clipPos = TransformObjectToHClip(v.vertex.xyz+outline_normal*0.01*_OutlineWidth);
                o.pos = clipPos;
            	o.color = float4(outline_normal,v.color.a);
                return o;
            }

            half4 fragOutline (vertexOutputOutline i) : SV_TARGET
            {
                return _OutlineColor;
            }
            
            ENDHLSL
        }
    }
}