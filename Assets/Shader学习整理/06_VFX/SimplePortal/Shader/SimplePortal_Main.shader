Shader "URP/SimplePortal"
{
    Properties
    {
        [HDR]_BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _MainMask("MainMask",2D) = "white"{}
        _RotationSpeed("Rotation Speed",float) = 1
        _RotationOffset("Rotation Offset",Range(-1,1)) = 0
        _RotationAxis("(Local) Rotation Axis",Vector) = (0,0,1)
        _VoroNoiseScale("VoroNoise Scale",float) = 5
        _VoroNoiseSpeed("VoroNoise Speed",float) = 1
        _VoroNoisePower("VoroNoise Power",float) = 1.5
        _VoroNoiseIntensity("VoroNoise Intensity",float) = 1
        _CenterDissolve("CenterDissolve",float) = 1.7
        _TwirlStrength("Twirl Strength",float) = 1
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
         
         pass
        {
            Lighting Off
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off
            ZWrite Off
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainMask);//定义贴图
            SAMPLER(sampler_MainMask);//定义采样器
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float4 _MainMask_ST;
            float _RotationSpeed;
            float3 _RotationAxis;
            float _RotationOffset;
            float _VoroNoiseScale;
            float _VoroNoiseSpeed;
            float _TwirlStrength;
            float _VoroNoiseIntensity;
            float _VoroNoisePower;
            float _CenterDissolve;
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

              inline float2 unity_voronoi_noise_randomVector (float2 UV, float offset)
            {
                float2x2 m = float2x2(15.27, 47.63, 99.41, 89.98);
                UV = frac(sin(mul(UV, m)) * 46839.32);
                return float2(sin(UV.y*+offset)*0.5+0.5, cos(UV.x*offset)*0.5+0.5);
            }

            void Unity_Voronoi_float(float2 UV, float AngleOffset, float CellDensity, out float Out, out float Cells)
            {
                float2 g = floor(UV * CellDensity);
                float2 f = frac(UV * CellDensity);
                float t = 8.0;
                float3 res = float3(8.0, 0.0, 0.0);

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
            }

            void Unity_Twirl_float(float2 UV, float2 Center, float Strength, float2 Offset, out float2 Out)
            {
                float2 delta = UV - Center;
                float angle = Strength * length(delta);
                float x = cos(angle) * delta.x - sin(angle) * delta.y;
                float y = sin(angle) * delta.x + cos(angle) * delta.y;
                Out = float2(x + Center.x + Offset.x, y + Center.y + Offset.y);
            }

            void Unity_PolarCoordinates_float(float2 UV, float2 Center, float RadialScale, float LengthScale, out float2 Out)
            {
                float2 delta = UV - Center;
                float radius = length(delta) * 2 * RadialScale;
                float angle = atan2(delta.x, delta.y) * 1.0/6.28 * LengthScale;
                Out = float2(radius, angle);
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
                float3x3 rotationMaterix = AngleAxis3x3((frac(_Time.y*_RotationSpeed)+_RotationOffset)*2.0f*PI,_RotationAxis);
                v.vertex.xyz = mul(rotationMaterix,v.vertex.xyz);
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            float4 frag (vertexOutput i) : SV_TARGET
            {
                float2 twirlUV, polarCoordinatesUV;
                Unity_PolarCoordinates_float(i.uv,float2(0.5,0.5),1.12,0.81,polarCoordinatesUV);
                Unity_Twirl_float(i.uv,float2(0.5,0.5),_TwirlStrength,float2(0,0),twirlUV);

                float outCircleMask = 1-polarCoordinatesUV;
                float centerCircleMask = pow(polarCoordinatesUV,_CenterDissolve);
                
                float voronoise, cells;
                Unity_Voronoi_float(twirlUV,_Time.y*_VoroNoiseSpeed, _VoroNoiseScale, voronoise, cells);
                voronoise = pow(voronoise*_VoroNoiseIntensity,_VoroNoisePower);
                float mainMask = SAMPLE_TEXTURE2D(_MainMask,sampler_MainMask,i.uv*_MainMask_ST.xy+_MainMask_ST.zw).a;
                float3 finalRGB = _BaseColor*voronoise*mainMask*centerCircleMask;
                float finalAlpha = saturate(voronoise*mainMask*centerCircleMask);
                float4 result = float4(finalRGB,finalAlpha);
                return result;
            }
            
            ENDHLSL
        }
    }
}