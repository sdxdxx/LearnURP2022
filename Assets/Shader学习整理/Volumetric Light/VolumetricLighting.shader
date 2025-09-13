Shader "URP/VolumetricLighting"
{
    Properties
    {
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _MainTex("MainTex",2D) = "white"{}
        
        [Header(Cone)]
        [Vector3]_pa("pa",Vector) = (5,5,1)
        [Vector3]_pb("pb",Vector) = (-5,-1,-2)
        _ra("ra",float) = 1
        _rb("rb",float) = 2
    }
    
    SubShader
    {
         Tags
        {
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }

         pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
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

            float3 _pa;
            float3 _pb;
            float _ra;
            float _rb;
            //----------变量声明结束-----------
            CBUFFER_END

            float dot2(float3 n)
            {
                return dot(n,n);
            }
            

            // cone defined by extremes pa and pb, and radious ra and rb Only one square root and one division is emplyed in the worst case. dot2(v) is dot(v,v)
            float4 coneIntersect( in float3 ro, in float3 rd, in float3 pa, in float3 pb, in float ra, in float rb )
            {
                float3  ba = pb - pa;  //圆台轴向向量（从A端到B端）
                float3  oa = ro - pa;  //射线原点相对A端的向量
                float3  ob = ro - pb;  //射线原点相对B端的向量
                float m0 = dot(ba,ba); //轴向长度的平方|ba|^2
                float m1 = dot(oa,ba); //oa在轴向上的投影（标量*|ba|^2）
                float m2 = dot(rd,ba); //rd在轴向上的投影
                float m3 = dot(rd,oa); //rd与oa的点积
                float m5 = dot(oa,oa); //|oa|2
                float m9 = dot(ob,ba); //ob在轴向上的投影
                
                // caps
                if( m1<0.0 )
                {
                    if( dot2(oa*m2-rd*m1)<(ra*ra*m2*m2) ) // delayed division
                        return float4(-m1/m2,-ba*rsqrt(m0));
                }
                else if( m9>0.0 )
                {
    	            float t = -m9/m2;                     // NOT delayed division
                    if( dot2(ob+rd*t)<(rb*rb) )
                        return float4(t,ba*rsqrt(m0));
                }
                
                // body
                float rr = ra - rb; //圆锥两个面的半径差
                float hy = m0 + rr*rr; 
                float k2 = m0*m0    - m2*m2*hy;
                float k1 = m0*m0*m3 - m1*m2*hy + m0*ra*(rr*m2*1.0        );
                float k0 = m0*m0*m5 - m1*m1*hy + m0*ra*(rr*m1*2.0 - m0*ra);
                float h = k1*k1 - k2*k0;
                if( h<0.0 )
                    return -1; //no intersection
                float t1 = (-k1-sqrt(h))/k2;
                float t2 = (-k1+sqrt(h))/k2;
                
                float y1 = m1 + t1*m2;
                
                if (y1<0.0 || y1>m0)
                    return -1; //no intersection
                
                
                return float4(t1,t2,0,1);
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
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv*_MainTex_ST.xy+_MainTex_ST.zw;
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                o.posWS = positionWS;
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                half4 albedo = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv);
                float3 vDirWS = normalize(i.posWS- _WorldSpaceCameraPos);
                float3 ro = _WorldSpaceCameraPos;
                float3 rd = vDirWS;
                float3 pa = _pa;
                float3 pb = _pb;
                float3 ra = _ra;
                float3 rb = _rb;

                float4 coneIntersection = coneIntersect(ro,rd,pa,pb,ra,rb);
                if (coneIntersection.z<0)
                {
                    discard;
                }

                float3 intersectionPoint1 = ro+rd*coneIntersection.x;
                float3 intersectionPoint2 = ro+rd*coneIntersection.y;
                return float4(_BaseColor.rgb,1.0);
                return albedo*_BaseColor;
            }
            
            ENDHLSL
        }
    }
}