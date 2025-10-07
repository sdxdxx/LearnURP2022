Shader "URP/VFX/Fire"
{
    Properties
    {
        [HDR]_BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        [HDR]OutFlameColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _NoiseFlowSpeed(" (XY):Distortion (ZW):Dissolve Speed",Vector) = (0.0,0.0,0.0,0.0)
        _DissolveScale("Dissolve Scale",float) = 2
        _DistortionScale("Distortion Scale",float) = 5
        _DissolveAmount("Dissolve Amount",float) = 1.2
        _DistortionAmount("Distortion Amount",Range(0,1)) = 0
        _MainTex("MainTex",2D) = "white"{}
    }
    
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
        }
        
         pass
        {
            Blend One One
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
            half4 OutFlameColor;
            float4 _MainTex_ST;

            float4 _NoiseFlowSpeed;
            float _DissolveScale;
            float _DistortionScale;
            float _DissolveAmount;
            float _DistortionAmount;
            //----------变量声明结束-----------
            CBUFFER_END

            float2 unity_gradientNoise_dir(float2 p)
            {
                p = p % 289;
                float x = (34 * p.x + 1) * p.x % 289 + p.y;
                x = (34 * x + 1) * x % 289;
                x = frac(x / 41) * 2 - 1;
                return normalize(float2(x - floor(x + 0.5), abs(x) - 0.5));
            }

            float unity_gradientNoise(float2 p)
            {
                float2 ip = floor(p);
                float2 fp = frac(p);
                float d00 = dot(unity_gradientNoise_dir(ip), fp);
                float d01 = dot(unity_gradientNoise_dir(ip + float2(0, 1)), fp - float2(0, 1));
                float d10 = dot(unity_gradientNoise_dir(ip + float2(1, 0)), fp - float2(1, 0));
                float d11 = dot(unity_gradientNoise_dir(ip + float2(1, 1)), fp - float2(1, 1));
                fp = fp * fp * fp * (fp * (fp * 6 - 15) + 10);
                return lerp(lerp(d00, d01, fp.y), lerp(d10, d11, fp.y), fp.x);
            }

            float Unity_GradientNoise_float(float2 UV, float Scale)
            {
                float result = unity_gradientNoise(UV * Scale) + 0.5;
                return result;
            }

            inline float2 unity_voronoi_noise_randomVector (float2 UV, float offset)
            {
                float2x2 m = float2x2(15.27, 47.63, 99.41, 89.98);
                UV = frac(sin(mul(UV, m)) * 46839.32);
                return float2(sin(UV.y*+offset)*0.5+0.5, cos(UV.x*offset)*0.5+0.5);
            }

            float Unity_Voronoi_float(float2 UV, float AngleOffset, float CellDensity)
            {
                float2 g = floor(UV * CellDensity);
                float2 f = frac(UV * CellDensity);
                float t = 8.0;
                float3 res = float3(8.0, 0.0, 0.0);

                float Out = 0;
                float Cells = 0;
                
                for(int y=-1; y<=1; y++)
                {
                    for(int x=-1; x<=1; x++)
                    {
                        float2 lattice = float2(x,y);
                        float2 offset = unity_voronoi_noise_randomVector(lattice + g, AngleOffset);
                        float d = distance(lattice + offset, f);
                        if(d < res.x)
                        {
                            res = float3(d, offset.x, offset.y);
                            Out = res.x;
                            Cells = res.y;
                        }
                    }
                }

                return Out;
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
                float3 newForwardDir = -normalize(TransformWorldToObject(_WorldSpaceCameraPos.xyz) - float3(0,0,0));
                float3 newRightDir = normalize(cross(float3(0,1,0),newForwardDir));
                float3 newUpDir = normalize(cross(newForwardDir,newRightDir));
                v.vertex.xyz =  v.vertex.x * newRightDir + v.vertex.y * newUpDir + v.vertex.z * newForwardDir;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                float3 originPointWS = TransformObjectToWorld(float3(0,0,0));
                float offset = originPointWS.x/originPointWS.z;
                float2 GradientNoise = Unity_GradientNoise_float(i.uv+_NoiseFlowSpeed.xy*_Time.x+offset,_DistortionScale);
                float2 albedoUV = i.uv*_MainTex_ST.xy+_MainTex_ST.zw;
                albedoUV = lerp(albedoUV,GradientNoise,_DistortionAmount);
                float albedo = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,albedoUV).r;

                float2 VoroNoise = Unity_Voronoi_float(i.uv+_NoiseFlowSpeed.zw*_Time.x+offset,2,_DissolveScale);
                VoroNoise = pow(VoroNoise,_DissolveAmount);
                float FinalNoise = VoroNoise*GradientNoise;

                albedo = FinalNoise*albedo;

                float outFlame = smoothstep(0.05,0.08,albedo)-smoothstep(0.08,0.1,albedo);

                half3 FinalRGB = albedo*_BaseColor.rgb+outFlame*OutFlameColor;
                half FinalAlpha = albedo*_BaseColor.a*FinalNoise;
                
                
                return half4(FinalRGB,FinalAlpha);
            }
            
            ENDHLSL
        }
    }
}