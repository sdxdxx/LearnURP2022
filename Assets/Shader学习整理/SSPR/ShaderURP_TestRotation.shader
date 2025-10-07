Shader "URP/TestRotation"
{
    Properties
    {
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _MainTex("Main Texture",2D) = "white"{}
        _RotationY("RotationY",float) = 0
    }
    
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "RenderPipeline" = "UniversalPipeline"  
        }

        //解决深度引动模式Depth Priming Mode问题
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/DepthNormals"
        
        pass
        {
            Tags{"LightMode"="UniversalForward"}
             
            HLSLPROGRAM
            

            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);//定义贴图
            SAMPLER(sampler_MainTex);//定义采样器
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float4 _MainTex_ST;
            float _RotationY;
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
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;

                float3 posWS0 =TransformObjectToWorld(float3(0,0,0));
                float3 posWS = TransformObjectToWorld(v.vertex.xyz);
                posWS -= posWS0;
                float3x3 mat = AngleAxis3x3(_RotationY,float3(0,1,0));
                posWS = mul(mat,posWS);
                posWS +=posWS0;
                v.vertex.xyz = TransformWorldToObject(posWS);
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv*_MainTex_ST.xy+_MainTex_ST.zw;
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                half4 albedo = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv);
                return albedo*_BaseColor;
            }
            
            ENDHLSL
        }
    }
}