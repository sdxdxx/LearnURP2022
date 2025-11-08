Shader "URP/ShaderURP_Water_SSR"
{
    Properties
    {
        [Header(Reflection)]
        _RefIntensity("RefIntensity",range(0,1)) = 0.6
        _Blur("BlurIntensity",float) = 0
        
    	[Header(Interactive)]
    	_RippleInt("Ripple Intensity(Vertex)",Range(0,1)) = 0.1
        
        [Header(Water Normal)]
        _NormalMap("Water Normal Map",2D) = "bump"{}
    	_NormalSpeed("Normal Speed",Vector) = (0.2,0.2,-0.33,-0.4)
        _NormalScale1("Normal Scale 1",float) = 10
        _NormalScale2("Normal Scale 2",float) = 7
        _NormalIntensity("Normal Intensity",Range(0,1)) = 0.5
        _NormalNoise("Normal Noise",Range(0,1)) = 0.68
        
        [Header(Water Color)]
        _ShallowColor("Shallow Color",color) = (1.0,1.0,1.0,1.0)
        _DeepColor("Deep Color",color) = (1.0,1.0,1.0,1.0)
        _WaterShallowRange("Water Shallow Range",range(0,5)) = 0.15
    	
    	[Header(Refraction)]
    	_RefractionInt("Refraction Intensity",Range(0,1)) = 1
        
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
    	
        
    	[Header(Light)]
    	_SpecInt("Specular Intensity",Range(0,1)) = 1
        _Smothness("Smothness",range(0,1)) = 0.5
    	_Metallic("Metallic",range(0,1)) = 0.5
        _SpecCol("Spec Col",color) = (1.0,1.0,1.0,1.0)
        _BlinkIntensity("Blink Intensity",float) = 1
        _BlinkThreshold("Blink Threshold",float) = 1
        
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
            
            float _RefIntensity;
            half4 _ShallowColor;
            half4 _DeepColor;
            float _WaterShallowRange;
            
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

    		float _RefractionInt;

            float _FoamRange;
            float _FoamFrequency;
            float _FoamSpeed;
            float _FoamBend;
            float _FoamDissolve;
            half4 _FoamCol;
            float4 _FoamNoise_ST;

    		float _SpecInt;
            float _Smothness;
            float _Metallic;
            half4 _SpecCol;
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

            //直接光镜面反射部分
            float3 CalculateSpecularResultColor(float3 albedo, float3 nDir, float3 lDir, float3 vDir, float smothness, float metallic, float3 specCol)
            {

            	float hDir = normalize(vDir+lDir);

            	float nDotl = max(saturate(dot(nDir,lDir)),0.000001);
				float nDotv = max(saturate(dot(nDir,vDir)),0.000001);
				float hDotv = max(saturate(dot(vDir,hDir)),0.000001);
            	
            	//粗糙度一家
				float perceptualRoughness = 1 - smothness;//粗糙度
				float roughness = perceptualRoughness * perceptualRoughness;//粗糙度二次方
				float squareRoughness = roughness * roughness;//粗糙度四次方
            	
				//法线分布函数NDF
				float lerpSquareRoughness = pow(lerp(0.002,1,roughness),2);
				//Unity把roughness lerp到了0.002,
				//目的是保证在smoothness为0表面完全光滑时也会留有一点点高光

				float D = lerpSquareRoughness / (pow((pow(dot(nDir,hDir),2)*(lerpSquareRoughness-1)+1),2)*PI);

				//几何(遮蔽)函数
				float kInDirectLight = pow(roughness+1,2)/8;
				float kInIBL = pow(roughness,2)/2;//IBL：间接光照
				float Gleft = nDotl / lerp(nDotl,1,kInDirectLight);
				float Gright = nDotv / lerp(nDotv,1,kInIBL);
				float G = Gleft*Gright;

            	//菲涅尔方程
				float3 F0 = lerp(kDielectricSpec.rgb, albedo, metallic);//使用Unity内置函数计算平面基础反射率
				float3 F = F0 + (1 - F0) *pow((1-hDotv),5);
            	

            	float3 SpecularResult = (D*G*F)/(4*nDotv*nDotl);

				 //因为之前少给漫反射除了一个PI，为保证漫反射和镜面反射比例所以多乘一个PI
				float3 specColor = SpecularResult * specCol * nDotl * PI;

            	return specColor;
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
            	
            	//Vector
                float3x3 TBN = float3x3(
                  i.tDirWS.x, i.bDirWS.x, i.nDirWS.x,
                  i.tDirWS.y, i.bDirWS.y, i.nDirWS.y,
                  i.tDirWS.z, i.bDirWS.z, i.nDirWS.z
                );
                
                float3 nDirWS = i.nDirWS;
            	
            	//WaterNormal
                float2 normalUV = i.posWS.xz;
            	float2 normalUV1 = frac(normalUV/_NormalScale1 + _NormalSpeed.xy*0.1*_Time.y);
            	float2 normalUV2 = frac(normalUV/_NormalScale2  + _NormalSpeed.zw*0.1*_Time.y);
                float4 NormalMap1 = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,normalUV1);
                float4 NormalMap2 = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,normalUV2);
                float3 var_NormalMap1 = UnpackScaleNormal(NormalMap1,_NormalIntensity);
                float3 var_NormalMap2 = UnpackScaleNormal(NormalMap2,_NormalIntensity);
                float3 waterNormal = NormalBlendReoriented(var_NormalMap1,var_NormalMap2);
            	//InteractiveNormal
            	float3 rippleNormal= SAMPLE_TEXTURE2D(_WaterRipple,sampler_WaterRipple,screenPos);
            	//BlendNormal
            	waterNormal = waterNormal+rippleNormal;
            	waterNormal = mul(TBN,waterNormal);
            	waterNormal = normalize(waterNormal);
            	
            	//ReflectionColor
            	float2 noiseUV = waterNormal.xz/(1+i.pos.w);
            	
            	//WaterDepth(Get Original Depth)
                float rawDepth0 = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp,screenPos).r;
                float3 posWS_frag0 = ReconstructWorldPositionFromDepth(i.screenPos,rawDepth0);
                float waterDepth0 = i.posWS.y - posWS_frag0.y;
            	
            	//Firstly Sample Depth Texture (Distortion)
            	float2 grabUV = screenPos;
            	grabUV.x += noiseUV*_NormalNoise;
            	float rawDepth1 =  SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp,grabUV).r;
            	
                float3 posWS_frag1 = ReconstructWorldPositionFromDepth(i.screenPos,rawDepth1);

            	//Get Reflection And Refraction Mask
            	float ReflectionAndReflectionMask = step(posWS_frag1.y,i.posWS.y);
            	grabUV = screenPos;
            	grabUV.x += noiseUV*_NormalNoise/max(i.screenPos.w,1.2f)*ReflectionAndReflectionMask*_RefractionInt;

            	//Secondly Sample Depth Texture (Remove the parts that should not be distorted)
            	float rawDepth2 =  SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp,grabUV).r;
                float3 posWS_frag2 = ReconstructWorldPositionFromDepth(i.screenPos,rawDepth2);

            	float waterDepth = i.posWS.y - posWS_frag2.y;
            	
            	//Caustics
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

            	//ReflectionColor
            	float2 reflectUV = screenPos;
            	reflectUV.x += noiseUV*_NormalNoise*ReflectionAndReflectionMask;
            	half4 refCol = SAMPLE_TEXTURE2D(_ScreenSpaceReflectionTexture,sampler_ScreenSpaceReflectionTexture,reflectUV);

            	//Refraction UnderWater
				half3 underWaterCol = SAMPLE_TEXTURE2D(_CameraOpaqueTexture,sampler_CameraOpaqueTexture,grabUV);
                underWaterCol = saturate(underWaterCol+CausiticsCol);
            	
            	//WaterColor
                float waterShallow_range =clamp(exp(-max(waterDepth0,waterDepth)/_WaterShallowRange),0,1);
                half4 waterCol = lerp(_DeepColor,_ShallowColor,waterShallow_range);
            	
            	//Light
                float3 nDir = waterNormal;
            	float3 lDir = _MainLightPosition.xyz;
            	float3 vDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
                float3 hDir = SafeNormalize(lDir+vDir);
                float nDoth = dot(nDir,hDir);
            	float halfLambert = saturate(dot(nDir,lDir)*0.5+0.5);
            	float halfLambert_Modified = remap(halfLambert,0,1,0.5,1);
            	float3 SpecLight = CalculateSpecularResultColor(waterCol,nDir,lDir,vDir,_Smothness,_Metallic, _SpecCol)*_SpecInt;
            	waterCol.rgb = lerp(waterCol,waterCol*0.5f+_ShallowColor*0.5f,saturate(exp(-distance(i.posWS.xyz,_WorldSpaceCameraPos.xyz))));
            	waterCol.rgb = lerp(refCol*saturate(waterCol+0.3),waterCol,1-_RefIntensity)*halfLambert_Modified;
            	
            	
            	float FinalA = waterCol.a;
            	
            	half3 WaterFinalColor = saturate(lerp(underWaterCol*waterCol,waterCol,FinalA)+SpecLight);

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

    		half4 frag_Back (vertexOutput i) : SV_TARGET
            {
            	float2 screenPos = i.screenPos.xy/i.screenPos.w;
            	
            	//Vector
                float3x3 TBN = float3x3(
                  i.tDirWS.x, i.bDirWS.x, i.nDirWS.x,
                  i.tDirWS.y, i.bDirWS.y, i.nDirWS.y,
                  i.tDirWS.z, i.bDirWS.z, i.nDirWS.z
                );
                
                float3 nDirWS = i.nDirWS;
                
            	
            	//WaterNormal
                float2 normalUV = i.posWS.xz;
            	float2 normalUV1 = frac(normalUV/_NormalScale1 + _NormalSpeed.xy*0.1*_Time.y);
            	float2 normalUV2 = frac(normalUV/_NormalScale2  + _NormalSpeed.zw*0.1*_Time.y);
                float4 NormalMap1 = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,normalUV1);
                float4 NormalMap2 = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,normalUV2);
                float3 var_NormalMap1 = UnpackScaleNormal(NormalMap1,_NormalIntensity);
                float3 var_NormalMap2 = UnpackScaleNormal(NormalMap2,_NormalIntensity);
                float3 waterNormal = NormalBlendReoriented(var_NormalMap1,var_NormalMap2);
            	//InteractiveNormal
            	float3 rippleNormal= SAMPLE_TEXTURE2D(_WaterRipple,sampler_WaterRipple,screenPos);
            	//BlendNormal
            	waterNormal = waterNormal+rippleNormal;
            	waterNormal = mul(TBN,waterNormal);
            	waterNormal = normalize(waterNormal);
            	
            	
            	//ReflectionColor
                 float2 noiseUV = waterNormal.xz/(1+i.pos.w);
            	float2 reflectUV = screenPos;
            	reflectUV.x += noiseUV*_NormalNoise;
            	half4 refCol = SAMPLE_TEXTURE2D(_ScreenSpaceReflectionTexture,sampler_ScreenSpaceReflectionTexture,reflectUV);
            	
            	//WaterDepth
                float rawDepth0 = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp,screenPos).r;
                float3 posWS_frag0 = ReconstructWorldPositionFromDepth(i.screenPos,rawDepth0);
                float waterDepth0 =  posWS_frag0.y- i.posWS.y;
            	
            	float2 grabUV = screenPos;
            	grabUV.x += noiseUV*_NormalNoise;
            	
            	//第一次次采样深度图（扰动）
            	float rawDepth1 =  SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp,grabUV).r;
                float3 posWS_frag1 = ReconstructWorldPositionFromDepth(i.screenPos,rawDepth1);
            	
            	float refractionMask = step(i.posWS.y,posWS_frag1.y);
            	grabUV = screenPos;
            	grabUV.x += noiseUV*_NormalNoise/max(i.screenPos.w,2.0f)*refractionMask*_RefractionInt;

            	//第二次次采样深度图（去除不该扰动部分）
            	float rawDepth2 =  SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp,grabUV).r;
                float3 posWS_frag2 = ReconstructWorldPositionFromDepth(i.screenPos,rawDepth2);
            	float waterDepth = posWS_frag2.y-i.posWS.y;
            	
            	//UnderWater
				half3 underWaterCol = SAMPLE_TEXTURE2D(_CameraOpaqueTexture,sampler_CameraOpaqueTexture,grabUV);
            	
            	//WaterColor
                half4 waterCol = _ShallowColor*0.2f+_DeepColor*0.8f;
            	
            	//Light
            	//优化模拟阳光映照水面效果
                float3 nDir = -waterNormal;
            	float3 lDir = -_MainLightPosition.xyz;
            	float3 vDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
                float3 hDir = SafeNormalize(lDir+vDir);
                float nDoth = dot(nDir,hDir);
            	float halfLambert = saturate(dot(nDir,lDir)*0.5+0.5);
            	float halfLambert_Modified = remap(halfLambert,0,1,0.5,1);
            	float3 SpecLight = CalculateSpecularResultColor(waterCol,nDir,lDir,vDir,_Smothness,_Metallic, _SpecCol)*_SpecInt;
            	
            	waterCol.rgb = lerp(refCol*saturate(waterCol+0.3),waterCol,(1-_RefIntensity*0.25f))*halfLambert_Modified;

            	float FinalA = waterCol.a;
            	
            	half3 waterFinalCol = saturate(lerp(underWaterCol*waterCol,waterCol,FinalA)+SpecLight);
            	
                //Blink
                float3 blinkNormal1 = var_NormalMap1;
                float3 blinkNormal2 = var_NormalMap2;
                float3 blinkNormal;
                blinkNormal.xy = (blinkNormal1.xy + blinkNormal2.xy)/2*_BlinkIntensity;
                blinkNormal.z = 1-sqrt(dot(blinkNormal.xy,blinkNormal.xy));
                blinkNormal = mul(TBN,blinkNormal);
                float2 blinkUV = blinkNormal.xz/(1+i.pos.w);
                half3 blink = SAMPLE_TEXTURE2D(_ScreenSpaceReflectionTexture,sampler_ScreenSpaceReflectionTexture,screenPos+blinkUV * _NormalNoise);
                blink = max(0,blink-_BlinkThreshold);//使用_BlinkThreshold去除不要的部分

            	//ShoreEdge
            	half3 shoreCol = _ShoreCol;
                float shoreRange = saturate(exp(-max(waterDepth0,waterDepth)/_ShoreRange));
                half3 shoreEdge = smoothstep(0.1,1-(_ShoreEdgeWidth-0.2),shoreRange)*shoreCol*_ShoreEdgeIntensity;
            	
            	//Foam
                float foamX = saturate(1-waterDepth/_FoamRange);
                float foamRange = 1-smoothstep(_FoamBend-0.1,1,saturate(max(waterDepth0,waterDepth)/_FoamRange));//Mask
            	
                float foamNoise = SAMPLE_TEXTURE2D(_FoamNoise,sampler_FoamNoise,i.posWS.xz*_FoamNoise_ST.xy+_FoamNoise_ST.zw);
                half4 foam = sin(_FoamFrequency*foamX-_FoamSpeed*_Time.y);
                foam = saturate(step(foamRange,foam+foamNoise-_FoamDissolve))*foamRange*_FoamCol;
            	
                half3 FinalRGB = saturate(waterFinalCol+foam+shoreEdge);
            	FinalRGB = FinalRGB+smoothstep(0.3,0.4,rippleNormal.b)*FinalRGB,
            	FinalRGB += blink;
            	half4 result = half4(FinalRGB,1.0);
            	
                return result;
            }
    	
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
    	
    	pass
        {
	        Name "WaterBack"

        	Cull Front
        	Tags{"LightMode" = "SRPDefaultUnlit"}

            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma hull hullProgram
            #pragma domain domainProgram
            #pragma fragment frag_Back
            
            ENDHLSL
        }

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
				float3 nDirWS = NormalizeNormalPerPixel(i.nDirWS);
				return float4(nDirWS,i.pos.z);
			}

            ENDHLSL
            
        }
    	
    	

    }
}