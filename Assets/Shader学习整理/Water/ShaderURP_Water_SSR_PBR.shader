Shader "URP/ShaderURP_Water_SSR_PBR"
{
    Properties
    {
    	[Header(Light)]
        _Smoothness("Smoothness",range(0,1)) = 0.5
        _BlinkIntensity("Blink Intensity",float) = 1
        _BlinkThreshold("Blink Threshold",float) = 1
    	
    	[Header(Water Color)]
        _ShallowColor("Shallow Color",color) = (1.0,1.0,1.0,1.0)
        _DeepColor("Deep Color",color) = (1.0,1.0,1.0,1.0)
    	_DepthDensity("Depth Density",Range(0.1,5)) = 1
    	_ColorGradientRange("Color Gradient Range",Range(1,10)) = 1
        
    	[Header(Interactive)]
    	_RippleInt("Ripple Intensity(Vertex)",Range(0,1)) = 0.1
        
        [Header(Water Normal)]
        _NormalMap("Water Normal Map",2D) = "bump"{}
    	_NormalSpeed("Normal Speed",Vector) = (0.2,0.2,-0.33,-0.4)
        _NormalScale1("Normal Scale 1",float) = 10
        _NormalScale2("Normal Scale 2",float) = 7
        _NormalIntensity("Normal Intensity",Range(0,1)) = 0.5
        _NormalNoise("Normal Noise",Range(0,1)) = 0.68
	    
        [Header(Causitics Tex)]
        _CausiticsTex("Causitics Tex",2D) = "black"{}
        _CausiticsScale("Causitics Scale",float) = 5.7
        _CausiticsRange("Causitics Range",float) = 2.15
         _CausiticsIntensity("Causitics Intensity",float) = 1.54
        _CausiticsSpeed("Causitics Speed",float) = 1
        
        [Header(Shore)]
        _ShoreCol("Shore Col",color) = (0,0,0,0)
        _ShoreRange("Shore Range",float) = 0.08
        _ShoreEdgeWidth("Shore Edge Width",range(-1,1)) = 0.02
        _ShoreEdgeIntensity("Shore Edge Intensity",range(0,1)) = 0.2
    	
    	[Header(Foam)]
    	_FoamNoise("Foam Noise",2D) = "white"{}
        _FoamRange("Foam Range",float) = 0.1
    	_FoamBend("Foam Bend",float) = 0.2
    	_FoamFrequency("Foam Frequency",float) = 1
    	_FoamSpeed("Foam Speed", float) = 1
    	_FoamDissolve("Foam Dissolve",Range(0,2)) = 0.2
    	_FoamCol("Foam Color",color) = (1,1,1,1)
    	
	    
    	[Header(Tess)]
    	_Tess("Tessellation", Range(1, 32)) = 20
    	_MaxTessDistance("Max Tess Distance", Range(1, 32)) = 20
        _MinTessDistance("Min Tess Distance", Range(1, 32)) = 1
    	
    	[Header(Wave)]
    	_WaveA ("Wave A (dir, steepness, wavelength)", Vector) = (0.2,0,0.1,2)
    	_WaveB ("Wave B", Vector) = (0,0.2,0.05,2)
		_WaveC ("Wave C", Vector) = (0.2,0.2,0.1,2)
        _WaveInt("Wave Intensity",Range(0,1)) = 1
    }
    
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "Queue"="Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }
        
    	HLSLINCLUDE
    	
    		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

    		#pragma require tessellation
    		#pragma multi_compile  _MAIN_LIGHT_SHADOWS
    		#pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
    		#pragma multi_compile  _SHADOWS_SOFT

    		#pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 4.6

            #define kDielectricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04)
            
            //----------贴图声明开始-----------
            TEXTURE2D(_CameraDepthTexture);
            TEXTURE2D(_CameraNormalsTexture);
            SAMPLER(sampler_CameraNormalsTexture);
            TEXTURE2D(_CameraOpaqueTexture);//获取到摄像机渲染画面的Texture
            SAMPLER(sampler_CameraOpaqueTexture);
            
            TEXTURE2D(_ScreenSpaceReflectionTexture);//定义贴图
            SAMPLER(sampler_ScreenSpaceReflectionTexture);//定义采样器
            
            
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
    		TEXTURE2D(_WaterRipple);
            SAMPLER(sampler_WaterRipple);
            TEXTURE2D(_CausiticsTex);
            SAMPLER(sampler_CausiticsTex);
    	
            TEXTURE2D(_FoamNoise);
            SAMPLER(sampler_FoamNoise);
    	
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
    		
            half4 _ShallowColor;
            half4 _DeepColor;
    		float _DepthDensity;
    		float _ColorGradientRange;
            
            float _NormalIntensity;
            float _NormalScale1;
            float _NormalScale2;
            float _NormalNoise;
            float4 _NormalSpeed;

    		float _RippleInt;
            
            float _Blur;
            float _CausiticsScale;
            float _CausiticsRange;
            float _CausiticsIntensity;
            float _CausiticsSpeed;
    	
            half4 _ShoreCol;
            float _ShoreRange;
            float _ShoreEdgeWidth;
            float _ShoreEdgeIntensity;
    		
            float _FoamRange;
            float _FoamFrequency;
            float _FoamSpeed;
            float _FoamBend;
            float _FoamDissolve;
            half4 _FoamCol;
            float4 _FoamNoise_ST;
    		
            float _Smoothness;
            float _BlinkIntensity;
            float _BlinkThreshold;

    		float _Tess;
    		float _MaxTessDistance;
            float _MinTessDistance;
    		
            float4 _WaveA;
            float4 _WaveB;
            float4 _WaveC;
            float _WaveInt;
            //----------变量声明结束-----------
            CBUFFER_END

             //Wave: https://catlikecoding.com/unity/tutorials/flow/waves/
            float3 GerstnerWave (float4 wave, float3 p, inout float3 tangent, inout float3 binormal)
            {
			    float steepness = wave.z;
			    float wavelength = wave.w;
			    float k = 2 * PI / wavelength;
				float c = sqrt(9.8 / k);
				float2 d = normalize(wave.xy);
				float f = k * (dot(d, p.xz) - c * _Time.y);
				float a = steepness / k;
				
				p.x += d.x * (a * cos(f));
				p.y = a * sin(f);
				p.z += d.y * (a * cos(f));

				tangent += float3(
					-d.x * d.x * (steepness * sin(f)),
					d.x * (steepness * cos(f)),
					-d.x * d.y * (steepness * sin(f))
				);
				binormal += float3(
					-d.x * d.y * (steepness * sin(f)),
					d.y * (steepness * cos(f)),
					-d.y * d.y * (steepness * sin(f))
				);
				return float3(
					d.x * (a * cos(f)),
					a * sin(f),
					d.y * (a * cos(f))
				);
			}
    		
    		float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
            {
				return F0 + (max(float3(1 ,1, 1) * (1 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
			}
    	
			float3 FresnelLerp (half3 F0, half3 F90, half cosA)
			{
			    half t = Pow4 (1 - cosA);   // FAST WAY
			    return lerp (F0, F90, t);
			}

			half3 CalculateWaterBxDF(
			    float3 nDir, 
			    float3 lDir, 
			    float3 vDir, 
			    half3 waterColor,    // 水体固有色 (现在它会受光照影响变明暗)
			    half3 lightCol, 
			    float smoothness, 
			    half3 refractionCol, // 背景色 (Background)
			    half3 refCol,        // 表面反射 (Skybox)
			    float shadow,
			    float transmission   // 1=清澈, 0=浑浊
			)
			{
            	float shadowRamp = 1;
			    float3 hDir = normalize(vDir + lDir);
			    float nDotl = max(saturate(dot(nDir, lDir)), 0.000001); // 0~1 的光照强度
			    float nDotv = max(saturate(dot(nDir, vDir)), 0.000001);
			    
			    // --- 1. 粗糙度与菲涅尔 ---
			    float perceptualRoughness = 1 - smoothness;
			    float roughness = perceptualRoughness * perceptualRoughness;
			    float lerpSquareRoughness = pow(lerp(0.002, 1, roughness), 2);

			    float F0_val = 0.02; 
			    float fresnelTerm = F0_val + (1.0 - F0_val) * pow(1.0 - nDotv, 5.0); 
			    
			    // --- 2. 漫反射 (Diffuse) - 卡通海洋的核心 ---
			    // 💡 技巧：对于卡通水，可以使用 Half-Lambert 防止背光面死黑
			    // float halfLambert = nDotl * 0.5 + 0.5; 
			    // float3 diffuseTerm = lightCol * halfLambert * shadow;
			    
			    // 标准 Lambert:
			    // Kd: 能量守恒系数。在PBR中，反射越强，折射(漫反射)越弱
			    // 如果想要更"卡通/塑料"的感觉，可以去掉 (1-fresnelTerm)
			    float3 kd = (1 - fresnelTerm) * (1.0 - 0.0); // assuming metallic is 0
			    float3 diffuseTerm = kd * lightCol * (nDotl*0.5+0.5) * shadowRamp; // 这里没有乘PI，防止过曝

			    // --- 3. 照亮水体 (Lit Water Volume) ---
			    // 关键逻辑：漫反射是用来照亮"浑浊水体"的，而不是照亮"水底石头"的
			    // 加上环境光(这里简单模拟为0.1的亮度，你可以传入专门的Ambient)
			    float3 ambient = lightCol * 0.1; 
			    float3 litWaterBody = waterColor * (diffuseTerm + ambient);

			    // --- 4. 高光 (Specular) ---
			    float D_denom = (pow(dot(nDir, hDir), 2) * (lerpSquareRoughness - 1) + 1);
			    float D = lerpSquareRoughness / (D_denom * D_denom * PI);
			    
			    float k = pow(roughness + 1, 2) / 8.0;
			    float G = (nDotl / (nDotl * (1-k) + k)) * (nDotv / (nDotv * (1-k) + k));
			    
			    // Specular Term
			    float3 directSpecular = (D * G * fresnelTerm) / (4 * nDotv * nDotl + 0.0001);
			    
			    // ⚠️ 你之前保留了 PI，我把它加回来了，如果你觉得高光太爆可以去掉
			    float3 specularResult = directSpecular * lightCol * nDotl * PI * shadowRamp;

			    // --- 5. 水下混合 (Under Water Mix) ---
			    // 逻辑：
			    // 如果水清澈 (transmission=1) -> 显示 refractionCol (不受水面法线漫反射影响)
			    // 如果水浑浊 (transmission=0) -> 显示 litWaterBody (受漫反射影响，有波浪立体感)
			    half3 underWaterColor = lerp(litWaterBody, refractionCol, transmission); 
			    
			    // --- 6. 最终菲涅尔混合 ---
			    half3 finalColor = lerp(underWaterColor, refCol, fresnelTerm);
			    
			    // --- 7. 叠加高光 ---
			    finalColor += specularResult;

			    return finalColor;
			}

            //Remap
            float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
             {
               return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
             }

            float3 UnpackScaleNormal(float4 packedNormal, float bumpScale)
            {
	            float3 normal = UnpackNormal(packedNormal);
            	normal.xy *= bumpScale;
            	normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));
            	return normal;
            }

            float3 NormalBlendReoriented(float3 A, float3 B)
			{
				float3 t = A.xyz + float3(0.0, 0.0, 1.0);
				float3 u = B.xyz * float3(-1.0, -1.0, 1.0);
				return (t / t.z) * dot(t, u) - u;
			}

            float3 ReconstructWorldPositionFromDepth(float4 screenPos, float rawDepth)
            {
                float2 ndcPos = (screenPos/screenPos.w)*2-1;//map[0,1] -> [-1,1]
            	float3 worldPos;
                if (unity_OrthoParams.w)
                {
					float depth01 = 1-rawDepth;
                	float3 viewPos = float3(unity_OrthoParams.xy * ndcPos.xy, 0);
                	viewPos.z = -lerp(_ProjectionParams.y, _ProjectionParams.z, depth01);
                	worldPos = mul(UNITY_MATRIX_I_V, float4(viewPos, 1)).xyz;
                }
                else
                {
	                float depth01 = Linear01Depth(rawDepth,_ZBufferParams);
                	float3 clipPos = float3(ndcPos.x,ndcPos.y,1)*_ProjectionParams.z;// z = far plane = mvp result w
	                float3 viewPos = mul(unity_CameraInvProjection,clipPos.xyzz).xyz * depth01;
	                worldPos = mul(UNITY_MATRIX_I_V,float4(viewPos,1)).xyz;
                }
            	
                return worldPos;
            }
    	
            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            	float4 tangent : TANGENT;
            	float4 color : COLOR;
                float2 uv : TEXCOORD0;
            	
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
                float3 posWS : TEXCOORD2;
                float3 nDirWS : TEXCOORD3;
                float3 tDirWS : TEXCOORD4;
                float3 bDirWS : TEXCOORD5;
            };

    		 // 为了确定如何细分三角形，GPU使用了四个细分因子。三角形面片的每个边缘都有一个因数。
            // 三角形的内部也有一个因素。三个边缘向量必须作为具有SV_TessFactor语义的float数组传递。
            // 内部因素使用SV_InsideTessFactor语义
            struct TessellationFactors
            {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };

            // 该结构的其余部分与Attributes相同，只是使用INTERNALTESSPOS代替POSITION语意，否则编译器会报位置语义的重用
            struct ControlPoint
            {
                float4 vertex : INTERNALTESSPOS;
            	float3 normal : NORMAL;
            	float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
                
            };

    		ControlPoint vert(vertexInput v)
    		{
    			ControlPoint p;

    			p.vertex = v.vertex;
    			p.uv = v.uv;
    			p.normal = v.normal;
    			p.tangent = v.tangent;
    			p.color = v.color;

    			return p;
    		}

    		 // 随着距相机的距离减少细分数
            float CalcDistanceTessFactor(float4 vertex, float minDist, float maxDist, float tess)
            {
                float3 worldPosition = TransformObjectToWorld(vertex.xyz);
                float dist = distance(worldPosition,  GetCameraPositionWS());
                float f = clamp(1.0 - (dist - minDist) / (maxDist - minDist), 0.01, 1.0) * tess;
                return (f);
            }

    		// Patch Constant Function决定Patch的属性是如何细分的。这意味着它每个Patch仅被调用一次，
            // 而不是每个控制点被调用一次。这就是为什么它被称为常量函数，在整个Patch中都是常量的原因。
            // 实际上，此功能是与HullProgram并行运行的子阶段。
            // 三角形面片的细分方式由其细分因子控制。我们在MyPatchConstantFunction中确定这些因素。
            // 当前，我们根据其距离相机的位置来设置细分因子
            TessellationFactors MyPatchConstantFunction(InputPatch<ControlPoint, 3> patch)
            {
                float minDist = _MinTessDistance;
                float maxDist = _MaxTessDistance;
            
                TessellationFactors f;
            
                float edge0 = CalcDistanceTessFactor(patch[0].vertex, minDist, maxDist, _Tess);
                float edge1 = CalcDistanceTessFactor(patch[1].vertex, minDist, maxDist, _Tess);
                float edge2 = CalcDistanceTessFactor(patch[2].vertex, minDist, maxDist, _Tess);
            
                // make sure there are no gaps between different tessellated distances, by averaging the edges out.
                f.edge[0] = (edge1 + edge2) / 2;
                f.edge[1] = (edge2 + edge0) / 2;
                f.edge[2] = (edge0 + edge1) / 2;
                f.inside = (edge0 + edge1 + edge2) / 3;
                return f;
            }

            //细分阶段非常灵活，可以处理三角形，四边形或等值线。我们必须告诉它必须使用什么表面并提供必要的数据。
            //这是 hull 程序的工作。Hull 程序在曲面补丁上运行，该曲面补丁作为参数传递给它。
            //我们必须添加一个InputPatch参数才能实现这一点。Patch是网格顶点的集合。必须指定顶点的数据格式。
            //现在，我们将使用ControlPoint结构。在处理三角形时，每个补丁将包含三个顶点。此数量必须指定为InputPatch的第二个模板参数
            //Hull程序的工作是将所需的顶点数据传递到细分阶段。尽管向其提供了整个补丁，
            //但该函数一次仅应输出一个顶点。补丁中的每个顶点都会调用一次它，并带有一个附加参数，
            //该参数指定应该使用哪个控制点（顶点）。该参数是具有SV_OutputControlPointID语义的无符号整数。
            [domain("tri")]//明确地告诉编译器正在处理三角形，其他选项：
            [outputcontrolpoints(3)]//明确地告诉编译器每个补丁输出三个控制点
            [outputtopology("triangle_cw")]//当GPU创建新三角形时，它需要知道我们是否要按顺时针或逆时针定义它们
            [partitioning("fractional_odd")]//告知GPU应该如何分割补丁，现在，仅使用整数模式
            [patchconstantfunc("MyPatchConstantFunction")]//GPU还必须知道应将补丁切成多少部分。这不是一个恒定值，每个补丁可能有所不同。必须提供一个评估此值的函数，称为补丁常数函数（Patch Constant Functions）
            ControlPoint hullProgram(InputPatch<ControlPoint, 3> patch, uint id : SV_OutputControlPointID)
            {
                return patch[id];
            }

			vertexOutput AfterTessVertProgram (vertexInput v)
			{
				 vertexOutput o;
            	o.posWS = TransformObjectToWorld(v.vertex);

            	//Wave
            	float3 p = TransformObjectToWorld(v.vertex);
            	float3 tangent = v.tangent;
            	float3 binormal = normalize(cross(v.normal,v.tangent)*v.tangent.w);
            	p += GerstnerWave(_WaveA, p, tangent, binormal)*_WaveInt;
			    p += GerstnerWave(_WaveB, p, tangent, binormal)*_WaveInt;
			    p += GerstnerWave(_WaveC, p, tangent, binormal)*_WaveInt;
            	float3 normal = cross(binormal, tangent);

            	v.vertex.xyz = TransformWorldToObject(p);
            	float4 posCS = TransformObjectToHClip(v.vertex.xyz);
            	o.screenPos = ComputeScreenPos(posCS);
            	
            	//Interactive Water
            	float rippleHeight  = SAMPLE_TEXTURE2D_LOD(_WaterRipple,sampler_PointClamp,o.screenPos.xy/o.screenPos.w,0).x;
            	p.y+=rippleHeight*_RippleInt*0.1f;

            	v.vertex.xyz = TransformWorldToObject(p);
            	
                posCS = TransformObjectToHClip(v.vertex.xyz);
                o.pos = posCS;
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
            	o.tDirWS = normalize(TransformObjectToWorld(v.tangent));
            	o.bDirWS = normalize(cross(o.nDirWS,o.tDirWS)*v.tangent.w);
                o.uv = v.uv;
                o.screenPos = ComputeScreenPos(posCS);
                return o;
			}

            //HUll着色器只是使曲面细分工作所需的一部分。一旦细分阶段确定了应如何细分补丁，
            //则由Domain着色器来评估结果并生成最终三角形的顶点。
            //Domain程序将获得使用的细分因子以及原始补丁的信息，原始补丁在这种情况下为OutputPatch类型。
            //细分阶段确定补丁的细分方式时，不会产生任何新的顶点。相反，它会为这些顶点提供重心坐标。
            //使用这些坐标来导出最终顶点取决于域着色器。为了使之成为可能，每个顶点都会调用一次域函数，并为其提供重心坐标。
            //它们具有SV_DomainLocation语义。
            //在Demain函数里面，我们必须生成最终的顶点数据。
            [domain("tri")]//Hull着色器和Domain着色器都作用于相同的域，即三角形。我们通过domain属性再次发出信号
            vertexOutput domainProgram(TessellationFactors factors, OutputPatch<ControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
            {
                vertexInput v;
        
                //为了找到该顶点的位置，我们必须使用重心坐标在原始三角形范围内进行插值。
                //X，Y和Z坐标确定第一，第二和第三控制点的权重。
                //以相同的方式插值所有顶点数据。让我们为此定义一个方便的宏，该宏可用于所有矢量大小。
                #define DomainInterpolate(fieldName) v.fieldName = \
                        patch[0].fieldName * barycentricCoordinates.x + \
                        patch[1].fieldName * barycentricCoordinates.y + \
                        patch[2].fieldName * barycentricCoordinates.z;
    
                    //对位置、颜色、UV、法线等进行插值
                    DomainInterpolate(vertex)
                    DomainInterpolate(uv)
                    DomainInterpolate(color)
                    DomainInterpolate(normal)
    				DomainInterpolate(tangent);
                    
                    //现在，我们有了一个新的顶点，该顶点将在此阶段之后发送到几何程序或插值器。
                    //但是这些程序需要Varyings数据，而不是Attributes。为了解决这个问题，
                    //我们让域着色器接管了原始顶点程序的职责。
                    //这是通过调用其中的AfterTessVertProgram（与其他任何函数一样）并返回其结果来完成的。
                    return AfterTessVertProgram(v);
            }
    		
            half4 frag (vertexOutput i) : SV_TARGET
            {
				float2 screenPos = i.screenPos.xy/i.screenPos.w;
	            
	            // --- 1. Vector Setup (Moved Up for Physics Calc) ---
	            float3 vDirWS = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
	            
	            float3x3 TBN = float3x3(
	              i.tDirWS.x, i.bDirWS.x, i.nDirWS.x,
	              i.tDirWS.y, i.bDirWS.y, i.nDirWS.y,
	              i.tDirWS.z, i.bDirWS.z, i.nDirWS.z
	            );
	            
	            // --- 2. Water Normal ---
	            float2 normalUV = i.posWS.xz;
	            float2 normalUV1 = normalUV/_NormalScale1 + frac(_NormalSpeed.xy*0.1*_Time.y);
	            float2 normalUV2 = normalUV/_NormalScale2 + frac(_NormalSpeed.zw*0.1*_Time.y);
	            float4 NormalMap1 = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,normalUV1);
	            float4 NormalMap2 = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,normalUV2);
	            float3 var_NormalMap1 = UnpackScaleNormal(NormalMap1,_NormalIntensity);
	            float3 var_NormalMap2 = UnpackScaleNormal(NormalMap2,_NormalIntensity);
	            float3 waterNormal = NormalBlendReoriented(var_NormalMap1,var_NormalMap2);
            	
	            // Interactive Ripples
	            float3 rippleNormal= SAMPLE_TEXTURE2D(_WaterRipple,sampler_WaterRipple,screenPos);
	            
	            // Blend & Transform Normal
	            waterNormal = waterNormal + rippleNormal;
	            waterNormal = mul(TBN, waterNormal);
	            waterNormal = normalize(waterNormal);
            	
	            
	            float2 noiseUV = waterNormal.xz/(1+i.pos.w);
	            
	            // --- 3. Depth & Distortion ---
	            // Get Original Depth
	            float rawDepth0 = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp,screenPos).r;
	            float3 posWS_frag0 = ReconstructWorldPositionFromDepth(i.screenPos,rawDepth0);
	            float waterDepth0 = i.posWS.y - posWS_frag0.y;
	            
	            // Firstly Sample Depth Texture (Distortion)
	            float2 grabUV = screenPos;
	            grabUV.x += noiseUV*_NormalNoise;
	            float rawDepth1 =  SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp,grabUV).r;
	            float3 posWS_frag1 = ReconstructWorldPositionFromDepth(i.screenPos,rawDepth1);

	            // Get Reflection And Refraction Mask
	            float refractionMask = step(posWS_frag1.y, i.posWS.y);
	            // Apply mask to UV jitter
	            grabUV = screenPos;
	            grabUV.x += noiseUV*_NormalNoise/max(i.screenPos.w,1.2f) * refractionMask;

	            // Secondly Sample Depth Texture (The clean depth for logic)
	            float rawDepth2 =  SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp,grabUV).r;
	            float3 posWS_frag2 = ReconstructWorldPositionFromDepth(i.screenPos,rawDepth2);
	            
	            // 最终用于计算颜色的物理深度 (Vertical Depth)
	            float waterDepth = i.posWS.y - posWS_frag2.y;
	            
	            // --- 4. Caustics & Background ---
	            float causitics_range = saturate(exp(-waterDepth/_CausiticsRange));
	            float2 causiticsUV = posWS_frag2.xz/_CausiticsScale;
	            float2 causiticsUV1 = causiticsUV+frac(_Time.x*_CausiticsSpeed);
	            float2 causiticsUV2 = causiticsUV-frac(_Time.x*_CausiticsSpeed);
	            half3 CausiticsCol1 = SAMPLE_TEXTURE2D(_CausiticsTex,sampler_CausiticsTex,causiticsUV1+float2(0.1f,0.2f));
	            half3 CausiticsCol2 = SAMPLE_TEXTURE2D(_CausiticsTex,sampler_CausiticsTex,causiticsUV2);
	            float3 CameraNormal = SAMPLE_TEXTURE2D(_CameraNormalsTexture,sampler_CameraNormalsTexture,grabUV);
	            float CausticsMask1 = saturate(CameraNormal.y*CameraNormal.y);
	            float CausticsMask2 = saturate(dot(CameraNormal,_MainLightPosition));
	            float CausticsMask = CausticsMask1*CausticsMask2;
	            half3 CausiticsCol = min(CausiticsCol1,CausiticsCol2)*causitics_range*_CausiticsIntensity*CausticsMask;

	            // Refraction UnderWater (Background + Caustics)
	            half3 underWaterCol = SAMPLE_TEXTURE2D(_CameraOpaqueTexture,sampler_CameraOpaqueTexture,grabUV);
	            underWaterCol = saturate(underWaterCol + CausiticsCol);
	            
	            // Reflection Color
	            float2 reflectUV = screenPos;
	            half4 refCol = SAMPLE_TEXTURE2D(_ScreenSpaceReflectionTexture,sampler_ScreenSpaceReflectionTexture,reflectUV);
            	
	            // ==========================================================
	            // --- 5. Water Physics Color (Corrected Logic) ---
	            // ==========================================================
	            
	            // A. 计算光线在水下的实际路径长度 (View Path Length)
	            // 垂直深度 (Vertical Depth)
	            float verticalDepth = max(waterDepth, 0.0);
	            // 视线角度修正 (Slant Factor): 角度越平，NdotV越小，路径越长
	            float NdotV = max(dot(waterNormal, vDirWS), 0.001); 
	            float viewPathLength = verticalDepth / NdotV;

	            // B. 计算透光率 (Transmission) - Beer-Lambert Law
	            // _DepthDensity 越大，水越混浊，吸收越快 (建议范围 0.1 ~ 5.0)
            	// transmission = 1 (清澈/浅), transmission = 0 (浑浊/深)
	            float transmission = exp(-viewPathLength * _DepthDensity);

	            // C. 计算水体固有色 (Volume Color)
	            // 仅基于垂直深度决定是浅水色还是深水色
	            // _ColorGradientRange 控制颜色过渡的深度 (建议范围 1.0 ~ 10.0)
            	float colorGradient =1-clamp(exp(-max(0,verticalDepth)/_ColorGradientRange),0,1);
	            half3 volumeColor = lerp(_ShallowColor.rgb, _DeepColor.rgb, colorGradient);
            	
	            // ==========================================================

	            // Metallic & Smoothness
	            float smoothness = _Smoothness;
	            
	            // MainLight
	            float4 shadowCoord = TransformWorldToShadowCoord(i.posWS);
	            Light mainLight = GetMainLight(shadowCoord);
	            half3 mainLightColor = mainLight.color;
	            float3 mainLightDir = mainLight.direction;
	            float mainLightShadow = MainLightRealtimeShadow(shadowCoord);
	            float3 mainLightRadiance = mainLightColor * mainLight.distanceAttenuation;
	            
	            // Final Physics Calculation
	            // 注意：参数已更新，不再传递错误的 Lerp 结果，而是传递物理参数
	            // 参数顺序: Normal, LightDir, ViewDir, Albedo(0), LightColor, Smoothness, Metallic(0), RefractionBG, Reflection, VolumeColor, Shadow, Transmission
	            half3 WaterFinalColor = CalculateWaterBxDF(
	                waterNormal, 
	                mainLightDir, 
	                vDirWS, 
	                volumeColor, 
	                mainLightRadiance,
	                smoothness, 
	                underWaterCol,
	                refCol.rgb,
	                mainLightShadow, 
	                transmission
	            );
            	
            	
            	//blink
                float3 blinkNormal1 = var_NormalMap1;
                float3 blinkNormal2 = var_NormalMap2;
                float3 blinkNormal;
                blinkNormal.xy = (blinkNormal1.xy + blinkNormal2.xy)/2*_BlinkIntensity;
                blinkNormal.z = 1-sqrt(dot(blinkNormal.xy,blinkNormal.xy));
                blinkNormal = mul(TBN,blinkNormal);
                float2 blinkUV = blinkNormal.xz/(1+i.pos.w);
                half3 blink = SAMPLE_TEXTURE2D(_ScreenSpaceReflectionTexture,sampler_ScreenSpaceReflectionTexture,screenPos+blinkUV * _NormalNoise);
                blink = max(0,blink-_BlinkThreshold);//Use _BlinkThreshold to remove unnecessary part
             
            	//ShoreEdge
            	half3 shoreCol = _ShoreCol;
                float shoreRange = saturate(exp(-max(waterDepth0,waterDepth)/_ShoreRange));
                half3 shoreEdge = smoothstep(0.1,1-(_ShoreEdgeWidth-0.2),shoreRange)*shoreCol*_ShoreEdgeIntensity;
             
            	//Foam
                float foamX = saturate(1-waterDepth/_FoamRange);
                float foamRange = 1-smoothstep(_FoamBend-0.1,1,saturate(max(waterDepth0,waterDepth)/_FoamRange));//遮罩
                float foamNoise = SAMPLE_TEXTURE2D(_FoamNoise,sampler_FoamNoise,i.posWS.xz*_FoamNoise_ST.xy+_FoamNoise_ST.zw);
                half4 foam = sin(_FoamFrequency*foamX-_FoamSpeed*_Time.y);
                foam = saturate(step(foamRange,foam+foamNoise-_FoamDissolve))*foamRange*_FoamCol;
            	
                half3 FinalRGB = saturate(WaterFinalColor+shoreEdge+foam);
            	FinalRGB = FinalRGB+smoothstep(0.3,0.4,rippleNormal.b)*FinalRGB,
            	FinalRGB += blink;
            	
            	half4 result = half4(FinalRGB,1.0);
            	
                return result;
            }

    // 		half4 frag_Back (vertexOutput i) : SV_TARGET
    //         {
    //         	float2 screenPos = i.screenPos.xy/i.screenPos.w;
    //         	
    //         	//Vector
    //             float3x3 TBN = float3x3(
    //               i.tDirWS.x, i.bDirWS.x, i.nDirWS.x,
    //               i.tDirWS.y, i.bDirWS.y, i.nDirWS.y,
    //               i.tDirWS.z, i.bDirWS.z, i.nDirWS.z
    //             );
    //             
    //             float3 nDirWS = i.nDirWS;
    //             
    //         	
    //         	//WaterNormal
    //             float2 normalUV = i.posWS.xz;
    //         	float2 normalUV1 = normalUV/_NormalScale1 + frac(_NormalSpeed.xy*0.1*_Time.y);
    //         	float2 normalUV2 = normalUV/_NormalScale2 + frac(_NormalSpeed.zw*0.1*_Time.y);
    //             float4 NormalMap1 = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,normalUV1);
    //             float4 NormalMap2 = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,normalUV2);
    //             float3 var_NormalMap1 = UnpackScaleNormal(NormalMap1,_NormalIntensity);
    //             float3 var_NormalMap2 = UnpackScaleNormal(NormalMap2,_NormalIntensity);
    //             float3 waterNormal = NormalBlendReoriented(var_NormalMap1,var_NormalMap2);
    //         	//InteractiveNormal
    //         	float3 rippleNormal= SAMPLE_TEXTURE2D(_WaterRipple,sampler_WaterRipple,screenPos);
    //         	//BlendNormal
    //         	waterNormal = waterNormal+rippleNormal;
    //         	waterNormal = mul(TBN,waterNormal);
    //         	waterNormal = normalize(waterNormal);
    //         	
    //         	
    //         	//ReflectionColor
    //              float2 noiseUV = waterNormal.xz/(1+i.pos.w);
    //         	float2 reflectUV = screenPos;
    //         	reflectUV.x += noiseUV*_NormalNoise;
    //         	half4 refCol = SAMPLE_TEXTURE2D(_ScreenSpaceReflectionTexture,sampler_ScreenSpaceReflectionTexture,reflectUV);
    //         	
    //         	//WaterDepth
    //             float rawDepth0 = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp,screenPos).r;
    //             float3 posWS_frag0 = ReconstructWorldPositionFromDepth(i.screenPos,rawDepth0);
    //             float waterDepth0 =  posWS_frag0.y- i.posWS.y;
    //         	
    //         	float2 grabUV = screenPos;
    //         	grabUV.x += noiseUV*_NormalNoise;
    //         	
    //         	//第一次次采样深度图（扰动）
    //         	float rawDepth1 =  SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp,grabUV).r;
    //             float3 posWS_frag1 = ReconstructWorldPositionFromDepth(i.screenPos,rawDepth1);
    //         	
    //         	float refractionMask = step(i.posWS.y,posWS_frag1.y);
    //         	grabUV = screenPos;
    //         	grabUV.x += noiseUV*_NormalNoise/max(i.screenPos.w,2.0f)*refractionMask;
    //
    //         	//第二次次采样深度图（去除不该扰动部分）
    //         	float rawDepth2 =  SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp,grabUV).r;
    //             float3 posWS_frag2 = ReconstructWorldPositionFromDepth(i.screenPos,rawDepth2);
    //         	float waterDepth = posWS_frag2.y-i.posWS.y;
    //         	
    //         	//UnderWater
				// half3 underWaterCol = SAMPLE_TEXTURE2D(_CameraOpaqueTexture,sampler_CameraOpaqueTexture,grabUV);
    //         	
    //         	//WaterColor
    //             half4 waterCol = _ShallowColor*0.2f+_DeepColor*0.8f;
    //         	
    //         	//Light
    //         	//优化模拟阳光映照水面效果
    //             float3 nDir = -waterNormal;
    //         	float3 lDir = -_MainLightPosition.xyz;
    //         	float3 vDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
    //             float3 hDir = SafeNormalize(lDir+vDir);
    //             float nDoth = dot(nDir,hDir);
    //         	float halfLambert = saturate(dot(nDir,lDir)*0.5+0.5);
    //         	float halfLambert_Modified = remap(halfLambert,0,1,0.5,1);
    //         	float3 SpecLight = CalculateSpecularResultColor(waterCol,nDir,lDir,vDir,_Smoothness,_Metallic, _SpecCol)*_SpecInt;
    //         	
    //         	waterCol.rgb = lerp(refCol*saturate(waterCol+0.3),waterCol,(1-_RefIntensity*0.25f))*halfLambert_Modified;
    //
    //         	float FinalA = waterCol.a;
    //         	
    //         	half3 waterFinalCol = saturate(lerp(underWaterCol*waterCol,waterCol,FinalA)+SpecLight);
    //         	
    //             //Blink
    //             float3 blinkNormal1 = var_NormalMap1;
    //             float3 blinkNormal2 = var_NormalMap2;
    //             float3 blinkNormal;
    //             blinkNormal.xy = (blinkNormal1.xy + blinkNormal2.xy)/2*_BlinkIntensity;
    //             blinkNormal.z = 1-sqrt(dot(blinkNormal.xy,blinkNormal.xy));
    //             blinkNormal = mul(TBN,blinkNormal);
    //             float2 blinkUV = blinkNormal.xz/(1+i.pos.w);
    //             half3 blink = SAMPLE_TEXTURE2D(_ScreenSpaceReflectionTexture,sampler_ScreenSpaceReflectionTexture,screenPos+blinkUV * _NormalNoise);
    //             blink = max(0,blink-_BlinkThreshold);//使用_BlinkThreshold去除不要的部分
    //
    //         	//ShoreEdge
    //         	half3 shoreCol = _ShoreCol;
    //             float shoreRange = saturate(exp(-max(waterDepth0,waterDepth)/_ShoreRange));
    //             half3 shoreEdge = smoothstep(0.1,1-(_ShoreEdgeWidth-0.2),shoreRange)*shoreCol*_ShoreEdgeIntensity;
    //         	
    //         	//Foam
    //             float foamX = saturate(1-waterDepth/_FoamRange);
    //             float foamRange = 1-smoothstep(_FoamBend-0.1,1,saturate(max(waterDepth0,waterDepth)/_FoamRange));//Mask
    //         	
    //             float foamNoise = SAMPLE_TEXTURE2D(_FoamNoise,sampler_FoamNoise,i.posWS.xz*_FoamNoise_ST.xy+_FoamNoise_ST.zw);
    //             half4 foam = sin(_FoamFrequency*foamX-_FoamSpeed*_Time.y);
    //             foam = saturate(step(foamRange,foam+foamNoise-_FoamDissolve))*foamRange*_FoamCol;
    //         	
    //             half3 FinalRGB = saturate(waterFinalCol+foam+shoreEdge);
    //         	FinalRGB = FinalRGB+smoothstep(0.3,0.4,rippleNormal.b)*FinalRGB,
    //         	FinalRGB += blink;
    //         	half4 result = half4(FinalRGB,1.0);
    //         	
    //             return result;
    //         }
    	
    	ENDHLSL
    	
    	pass
        {
	        Name "WaterMask"

        	Tags{"LightMode" = "WaterMask"}

            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma hull hullProgram
            #pragma domain domainProgram
            #pragma fragment frag_UnderWaterMask

            half4 frag_UnderWaterMask (vertexOutput i) : SV_TARGET
            {
            	return half4(1,1,1,1);
            }
            
            ENDHLSL
        }


        pass
        {
	        Name "WaterFront"

        	Cull Back
        	Tags{"LightMode" = "UniversalForward"}


            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma hull hullProgram
            #pragma domain domainProgram
            #pragma fragment frag
            
            ENDHLSL
        }
    	
//    	pass
//        {
//	        Name "WaterBack"
//
//        	Cull Front
//        	Tags{"LightMode" = "SRPDefaultUnlit"}
//
//            HLSLPROGRAM
//            
//            #pragma vertex vert
//            #pragma hull hullProgram
//            #pragma domain domainProgram
//            #pragma fragment frag_Back
//            
//            ENDHLSL
//        }

	    //DepthOnly
        pass
        {
        	Name "CustomDepthOnly"
            Tags
            {
                "LightMode" = "DepthOnly"
            }
	        
            ZWrite On
            ColorMask R
            Cull Off
            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex vert
            #pragma hull hullProgram
            #pragma domain domainProgram
            #pragma fragment frag_DepthOnly

            half4 frag_DepthOnly(vertexOutput i) : SV_TARGET
			{
				return i.pos.z;
			}
            
            ENDHLSL
        }

		//DepthNormals
		pass
        {
        	Name "CustomNormalsPass"

        	Tags{"LightMode" = "DepthNormals"}
        	Cull Off
            HLSLPROGRAM

            #pragma vertex vert
            #pragma hull hullProgram
            #pragma domain domainProgram
            #pragma fragment frag_DepthNormals

            half4 frag_DepthNormals(vertexOutput i) : SV_TARGET
			{
				float2 screenPos = i.screenPos.xy/i.screenPos.w;
				
	            float3x3 TBN = float3x3(
	              i.tDirWS.x, i.bDirWS.x, i.nDirWS.x,
	              i.tDirWS.y, i.bDirWS.y, i.nDirWS.y,
	              i.tDirWS.z, i.bDirWS.z, i.nDirWS.z
	            );
				
	            float2 normalUV = i.posWS.xz;
	            float2 normalUV1 = normalUV/_NormalScale1 + frac(_NormalSpeed.xy*0.1*_Time.y);
	            float2 normalUV2 = normalUV/_NormalScale2 + frac(_NormalSpeed.zw*0.1*_Time.y);
	            float4 NormalMap1 = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,normalUV1);
	            float4 NormalMap2 = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,normalUV2);
	            float3 var_NormalMap1 = UnpackScaleNormal(NormalMap1,_NormalIntensity*_NormalNoise);
	            float3 var_NormalMap2 = UnpackScaleNormal(NormalMap2,_NormalIntensity*_NormalNoise);
	            float3 waterNormal = NormalBlendReoriented(var_NormalMap1,var_NormalMap2);
				
	            float3 rippleNormal= SAMPLE_TEXTURE2D(_WaterRipple,sampler_WaterRipple,screenPos);
				
	            waterNormal = waterNormal + rippleNormal;
	            waterNormal = mul(TBN, waterNormal);
	            waterNormal = normalize(waterNormal);
				
				return float4(waterNormal,i.pos.z);
			}

            ENDHLSL
            
        }
    	
    	

    }
}