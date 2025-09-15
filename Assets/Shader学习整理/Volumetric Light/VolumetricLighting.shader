Shader "URP/VolumetricLighting"
{
    Properties
    {
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _MainTex("MainTex",2D) = "white"{}
        
        [Header(Cone)]
        [Vector3]_PositonA("PositonA",Vector) = (5,5,1)
        [Vector3]_PositonB("PositonB",Vector) = (-5,-1,-2)
        _RadiusA("RadiusA",float) = 1
        _RadiusB("RadiusB",float) = 2
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
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float4 _MainTex_ST;

            float _SpotRange;
            float3 _PositonA;
            float3 _PositonB;
            float _RadiusA;
            float _RadiusB;

            float _InnerRate;

            float _LightIntensity;
            //----------变量声明结束-----------
            CBUFFER_END

            float dot2(float3 n)
            {
                return dot(n,n);
            }

            // 通过三个点求平面法线
            float3 GetPlaneNormal(float3 p1, float3 p2, float3 p3)
            {
                // 构造两个边向量
                float3 a = p2 - p1;
                float3 b = p3 - p1;

                // 叉乘求法线
                float3 n = cross(a, b);

                // 单位化，避免零向量
                return normalize(n);
            }
            
            inline void TryInsertT(float t, inout float t0, inout float t1, float tMin)
            {
                if (t < tMin) return;          // 只收正向命中（或偏移后的正向）
                const float EPS = 1e-6;
                if (t + EPS < t0) { t1 = t0; t0 = t; }
                else if (t > t0 + EPS && t + EPS < t1) { t1 = t; }
            }
            // 计算封闭圆台（含两端盖）的最近两次射线命中 t
            // 输入：ro, rd（射线原点/方向，需同一坐标系；rd 不必单位化）
            //       pa, pb（两端圆心），ra, rb（对应半径）
            //       tMin（常用 0，或用作 shadow bias，如 1e-4）
            // 输出：ts.x 为最近 t，ts.y 为第二近 t（若不存在则为 +INF）
            // 返回：命中数量 0/1/2
            inline int coneIntersect2(float3 ro, float3 rd,float3 pa, float3 pb,float ra, float rb,float tMin,out float2 ts)
            {
                const float INF = 1e30;
                const float EPS = 1e-7;

                ts = float2(INF, INF);
                float t0 = INF, t1 = INF;

                // 轴向与常用量
                float3 ba = pb - pa;
                float3 oa = ro - pa;
                float3 ob = ro - pb;

                float m0 = dot(ba,ba);        // |ba|^2
                if (m0 <= 0.0) return 0;      // 退化：pa==pb，无交（或改成圆、圆盘的处理）

                float m1 = dot(oa,ba);
                float m2 = dot(rd,ba);
                float m3 = dot(rd,oa);
                float m5 = dot(oa,oa);
                float m9 = dot(ob,ba);

                // ---------- Caps：两端盖平面交 + 圆盘判定 ----------
                if (abs(m2) > EPS)
                {
                    // A 端盖（平面 (oa + t*rd)·ba = 0 -> tA = -m1/m2）
                    float tA = -m1 / m2;
                    float3 pA = oa + tA * rd;        // 相对 pa 的命中点
                    if (dot(pA, pA) <= ra*ra)        // 圆盘内
                        TryInsertT(tA, t0, t1, tMin);

                    //修改要求：B端盖变为球缺体 ，其补充回的球心为A点, 半径为AB 切割球缺体的平面为原B端盖的平面
                    
                    //-------------需要修改部分开始----------------
                     // B 端盖（平面 (ob + t*rd)·ba = 0 -> tB = -m9/m2）
                     // float tB = -m9 / m2;
                     // float3 pB = ob + tB * rd;        // 相对 pb 的命中点
                     // if (dot(pB, pB) <= rb*rb)        // 圆盘内
                     //     TryInsertT(tB, t0, t1, tMin);
                    //-------------需要修改部分结束----------------
                    
                    //-------------需要修改部分开始----------------
                    // B 端改为：以 A 点(pa)为球心、半径 Rc = sqrt(|AB|^2 + rb^2) 的“球缺体”
                    //（被原 B 端平面裁切，保留平面外侧，即 (ob + t*rd)·ba >= 0 的半空间）
                    // 这样球与该平面的交圆半径正好是 rb，对应“圆台 + 球缺体”的体积端部。
                    {
                        const float EPS_HALFSPACE = 1e-7;

                        float Rc = sqrt(m0 + rb*rb);          // m0 = dot(ba,ba) = |AB|^2

                        // 射线-球（球心 pa, 半径 Rc）：|oa + t*rd|^2 = Rc^2
                        float Aq = dot(rd, rd);
                        float Bq = 2.0 * dot(oa, rd);
                        float Cq = dot(oa, oa) - Rc*Rc;

                        float discS = Bq*Bq - 4.0*Aq*Cq;
                        if (discS >= 0.0)
                        {
                            float s = sqrt(discS);
                            float inv2A = 0.5 / Aq;

                            float tS0 = (-Bq - s) * inv2A;   // near
                            float3 pRelB0 = ob + tS0 * rd;   // 命中点相对 pb
                            if (dot(pRelB0, ba) >= -EPS_HALFSPACE)    // 平面外侧（朝 pb）
                                TryInsertT(tS0, t0, t1, tMin);

                            float tS1 = (-Bq + s) * inv2A;   // far
                            float3 pRelB1 = ob + tS1 * rd;
                            if (dot(pRelB1, ba) >= -EPS_HALFSPACE)
                                TryInsertT(tS1, t0, t1, tMin);
                        }
                    }
                    //-------------需要修改部分结束----------------
                }

                
                // ---------- Body：侧面（与你原公式一致） ----------
                float rr = ra - rb;
                float hy = m0 + rr*rr;

                float k2 = m0*m0    - m2*m2*hy;
                float k1 = m0*m0*m3 - m1*m2*hy + m0*ra*(rr*m2);
                float k0 = m0*m0*m5 - m1*m1*hy + m0*ra*(2.0*rr*m1 - m0*ra);

                float disc = k1*k1 - k2*k0;
                if (disc >= 0.0)
                {
                    if (abs(k2) < 1e-8)
                    {
                        // 二次退化为一次：2*k1*t + k0 = 0
                        if (abs(k1) > 1e-12)
                        {
                            float t = -k0 / (2.0*k1);
                            float y = m1 + t*m2;                 // 轴向参数（与 m0 同量纲）
                            if (y >= 0.0 && y <= m0)             // 在两端之间
                                TryInsertT(t, t0, t1, tMin);
                        }
                    }
                    else
                    {
                        float sH = sqrt(disc);
                        float tN = (-k1 - sH) / k2;              // near root
                        float tF = (-k1 + sH) / k2;              // far root

                        float yN = m1 + tN*m2;
                        if (yN >= 0.0 && yN <= m0)
                            TryInsertT(tN, t0, t1, tMin);

                        float yF = m1 + tF*m2;
                        if (yF >= 0.0 && yF <= m0)
                            TryInsertT(tF, t0, t1, tMin);
                    }
                }

                // ---------- 输出 ----------
                ts = float2(t0, t1);
                int count = 0;
                if (t0 < INF*0.5) count++;
                if (t1 < INF*0.5) count++;
                return count;
            }

            float InScatter(float3 start, float3 rd, float3 lightPos, float d)
            {
                float3 q = start - lightPos;
                float b = dot(rd, q);
                float c = dot(q, q);
                float iv = 1.0f / sqrt(c - b*b);
                float l = iv * (atan( (d + b) * iv) - atan( b*iv ));

                return l;
            }

            float3 ReconstructViewPositionFromDepth(float2 screenPos, float depth01)
            {
                float2 ndcPos = screenPos*2-1;//map[0,1] -> [-1,1]
            	float3 viewPos;
                if (unity_OrthoParams.w)
                {
                	viewPos = float3(unity_OrthoParams.xy * ndcPos.xy, 0);
                	viewPos.z = -lerp(_ProjectionParams.y, _ProjectionParams.z, depth01);
                }
                else
                {
                	float3 clipPos = float3(ndcPos.x,ndcPos.y,1)*_ProjectionParams.z;// z = far plane = mvp result w
	                viewPos = mul(unity_CameraInvProjection,clipPos.xyzz).xyz * depth01;
                }
            	
                return viewPos;
            }

            float GetDepth01(float rawDepth)
            {
            	float depth01;
	            if (unity_OrthoParams.w)
	            {
		             depth01 = 1-rawDepth;
	            }
	            else
	            {
		             depth01 = Linear01Depth(rawDepth,_ZBufferParams);
	            }

            	return depth01;
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
                float4 screenPos : TEXCOORD3;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                float4 posCS = TransformObjectToHClip(v.vertex.xyz);
                o.pos = posCS;
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv*_MainTex_ST.xy+_MainTex_ST.zw;
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                o.posWS = positionWS;
                o.screenPos = ComputeScreenPos(posCS);
                return o;
            }
            
            half4 frag (vertexOutput i) : SV_TARGET
            {
                half4 albedo = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv);
                float2 screenPos = i.screenPos.xy/i.screenPos.w;
                float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,screenPos);
                float depth01 = GetDepth01(rawDepth);
                float3 posVS_EnvironmentObject = ReconstructViewPositionFromDepth(screenPos,depth01);
                
                float3 vDirWS = normalize(i.posWS- _WorldSpaceCameraPos);//这是摄像机->物体的方向
                float3 ro = _WorldSpaceCameraPos;
                float3 rd = vDirWS;
                float3 pa = _PositonA;
                float3 pb = _PositonB;
                float ra = _RadiusA;
                float rb = _RadiusB;
                float spotRange = _SpotRange;
                float3 dirAB = normalize(pb-pa);

                float2 ts;
                int count = coneIntersect2(ro, rd, pa, pb, ra, rb, 0.0, ts);

                //未击中或者被遮挡则剔除
                if (count<=0 || ts.x>-posVS_EnvironmentObject.z)
                {
                    discard;
                }

                if (ts.y>-posVS_EnvironmentObject.z)
                {
                    ts.y = -posVS_EnvironmentObject.z;
                }

                float3 intersectionPoint1 = _WorldSpaceCameraPos+vDirWS*ts.x;
                float3 intersectionPoint2 = _WorldSpaceCameraPos+vDirWS*ts.y;
                
                //Scatter
                float d = distance(intersectionPoint1,intersectionPoint2);
                float scatter = InScatter(intersectionPoint1,rd,pa,d);
                scatter = min(0.8,scatter);

                
                //Edge Falloff
                float rangeOffset = ra*spotRange/(rb-ra);
                float realRange = spotRange+rangeOffset;
                float3 real_pa = pa-dirAB*rangeOffset;
                float3 nCut = GetPlaneNormal(intersectionPoint1,intersectionPoint2,real_pa);
                float3 dirAP = normalize(dirAB-dot(nCut,dirAB)*nCut);//P为由 光源位置A和射线与圆锥的两个交点构成的平面 和 圆锥底边 相交的 两点 的中点
                float cos1 = dot(dirAP,dirAB); //∠BAP的cos值
                float tan2 = rb/realRange;
                float cos2 = 1.0 / sqrt(1.0 + tan2 * tan2);
                float edgeFalloff = 1 - saturate((1 - cos1) / (1 - cos2) - _InnerRate);
                float orginalSpotRange = spotRange/(cos2*cos2);
                float simpleFalloff = distance(intersectionPoint1,pa+dirAB*orginalSpotRange)/orginalSpotRange;

                float4 result = float4(_BaseColor.rgb,scatter*edgeFalloff*simpleFalloff*_LightIntensity/20);
                return result;
            }
            
            ENDHLSL
        }
    }
}