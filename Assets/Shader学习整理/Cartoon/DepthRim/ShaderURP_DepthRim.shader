Shader "URP/DepthRim"
{
    Properties
    {
        _Width ("Width", Float) = 0
        _MinRange ("MinRange", Range(0, 1)) = 0 
        _MaxRange ("MaxRange", Range(0, 1)) = 1
        _Spread ("Spread", Float) = 1
        [HDR]_RimCol ("Rim Color", Color) = (1, 1, 1, 1)
        
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

            //引入URP的计算核心库，以此识别宏、以及变量名
             #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            //URP Light部分函数，返回Light 值
             #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

             struct appdata
            {
                 float4 vertex : POSITION;
                 float4 uv : TEXCOORD0;
                 half3 normal : NORMAL;          //法线
                 half4 tangent : TANGENT;        //切线
                 half4 color : COLOR0;           //顶点色

            };

             struct v2f
             {
                 float4 pos : SV_POSITION;
                 float2 uv : TEXCOORD0;
                 float4 scrPos : TEXCOORD5;
                 float3 worldPos : TEXCOORD1;        //世界坐标
                 float3 worldNormal : TEXCOORD2;     //世界空间法线
                 half4 color : COLOR0;               //顶点色
             };


             CBUFFER_START(UnityPerMaterial)
             sampler2D   _MainTex;
             float4  _MainTex_ST;

             float _Width;
            float _MinRange, _MaxRange, _Spread;
            float4 _RimCol;
            CBUFFER_END

             TEXTURE2D_X_FLOAT(_CameraDepthTexture);
             SAMPLER(sampler_CameraDepthTexture);

             v2f vert(appdata v)
             {
                 v2f o;
                 VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
                 VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(v.normal, v.tangent);
                 
                 o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                 o.pos = vertexInput.positionCS;

                 o.scrPos = ComputeScreenPos(vertexInput.positionCS);
             
                 o.worldPos = vertexInput.positionWS;
                 o.worldNormal = vertexNormalInput.normalWS;

                 o.color = v.color;     //顶点色

                 return o;
             }

             float4 frag(v2f i) : SV_Target
            {
                 //world normal 
                float3 wNor = normalize(i.worldNormal);
                //view normal 
                float3 vNor = mul(UNITY_MATRIX_V, float4(wNor, 0.0)).xyz;
                //screen pos 
                float2 scrPos = i.scrPos.xy / i.scrPos.w;
                scrPos += vNor.xy * _Width * 0.001;//uv offset 
                float depthTex = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,scrPos);
                float depthTex0 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,i.scrPos.xy / i.scrPos.w);
                float depth = LinearEyeDepth(depthTex,_ZBufferParams);//view space depth 
                float depth0 = LinearEyeDepth(depthTex0,_ZBufferParams);//view space depth 
                float rim = saturate((depth - depth0));//稍作缩放, 可以不要
                rim = smoothstep(min(_MinRange, 0.99), _MaxRange, rim);
                
                half4 col = 1;
                col.xyz = rim * _RimCol.xyz;
                //col.xyz = vNor;
                return col;
            }
             ENDHLSL
        }
        
}
}