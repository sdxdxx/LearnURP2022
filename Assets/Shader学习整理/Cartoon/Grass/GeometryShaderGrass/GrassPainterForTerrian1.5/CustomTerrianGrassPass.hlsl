	#define BLADE_SEGMENTS 4
	#define INTERACTIVE_COUNT 8
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
	#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
	#include "CustomTerrainLitInput.hlsl"
	#include "CustomTerrainLitPasses.hlsl"

	//----------贴图声明开始-----------
	TEXTURE2D(_WindDistortionMap);
	SAMPLER(sampler_WindDistortionMap);
	//----------贴图声明结束-----------

	CBUFFER_START(UnityPerMaterial)
	//----------变量声明开始-----------

	float3 _playerPos;
	float3 _interactiveCharacterPos[8];
	float _PushRadius;
	float _Strength;

	float _Lerp;

    half4 _GrassColorTint1; 
	half4 _TopColor1;
	half4 _BottomColor1;

    half4 _GrassColorTint2; 
	half4 _TopColor2;
	half4 _BottomColor2;

    half4 _GrassColorTint3; 
	half4 _TopColor3;
	half4 _BottomColor3;

    half4 _GrassColorTint4; 
	half4 _TopColor4;
	half4 _BottomColor4;

	float _ColorRandom;

	
	float _BladeHeightRandom;	
	float _BladeWidthRandom;
	float _BladeHeight1;
	float _BladeWidth1;
	float _BladeHeight2;
	float _BladeWidth2;
	float _BladeHeight3;
	float _BladeWidth3;
	float _BladeHeight4;
	float _BladeWidth4;

	float _BladeForward;
	float _BladeCurve;

	float  _BendRotationRandom;

	float4 _WindDistortionMap_ST;
	float2 _WindFrequency;
	float _WindStrength;

	int _GrassDensity1;
	int _GrassDensity2;
	int _GrassDensity3;
	int _GrassDensity4;

	float _TranslucentGain;
	//----------变量声明结束-----------
	CBUFFER_END

	//从一个三维输入生成一个随机数
	float rand(float3 co)
	{
	  return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
	}

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

	struct TessellationControlPoint
	{
		float4 positionOS : INTERNALTESSPOS;
		float3 normalOS : NORMAL;
	    float4 tangentOS : TANGENT;
		float2 texcoord : TEXCOORD0;
	};

	struct vertexOutputGrass
	{
	    float4 pos : SV_POSITION;
	    float3 normal : NORMAL;
	    float4 tangent : TANGENT;
	    float2 uv : TEXCOORD0;
	};

	TessellationControlPoint vert_Grass(Attributes v)
	{
	    TessellationControlPoint o;
	    o.positionOS = v.positionOS;
	    o.normalOS = v.normalOS;
	    o.tangentOS =v.tangentOS;
	    o.texcoord = v.texcoord;
	    return o;
	}

	 vertexOutputGrass vert_Grass_Output (TessellationControlPoint v)
	{
	    vertexOutputGrass o;
	     o.pos = v.positionOS;
	     o.normal = v.normalOS;
	     o.tangent = v.tangentOS;
	    o.uv = v.texcoord;
	    return o;
	}

	[domain("tri")]//定义细分的图元
	[outputcontrolpoints(3)]//定义hull shader 创建的输出控制点数量
	[outputtopology("triangle_cw")]//定义细分器所输出的图元类型point\line\triangle_cw\triangle_ccw
	[partitioning("fractional_odd")]//定义hull shader中使用的细分方案fractional_even，把一条边n等分\fractional_odd\pow2\integer
	[patchconstantfunc("patchConstantFunc")]//定义计算patch constant data的函数
	TessellationControlPoint hull_Grass(InputPatch<TessellationControlPoint, 3> patch, uint id : SV_OutputControlPointID)
	{
		return patch[id];
	}

	struct TessellationFactors 
	{
		float edge[3] : SV_TessFactor;
		float inside : SV_InsideTessFactor;
	};

	// This function lets us derive the tessellation factor for an edge
	// from the vertices.
	float tessellationEdgeFactor(TessellationControlPoint vert0, TessellationControlPoint vert1, float density)
	{
		float3 v0 = vert0.positionOS.xyz;
		float3 v1 = vert1.positionOS.xyz;
		float edgeLength = distance(v0, v1);

		//float2 vertexXZ = v0.xz;
		//float disVertexAndCamera = distance(vertexXZ, _WorldSpaceCameraPos.xz);
		//float tessClamp = clamp((1.0 - (disVertexAndCamera - 10) / (_GrassDistanceMax - _GrassDistanceMin)),0.5,1.0);
		
		return edgeLength * density;
	}

	//增加边缘的控制点，同时图元内部将会增加新的层
	    bool needTessellation(TessellationControlPoint v, out float density)
	{
		density = 0;
		
		float2 splatUV = (v.texcoord * (_Control_TexelSize.zw - 1.0f) + 0.5f) * _Control_TexelSize.xy;
		float4 splatControl = SAMPLE_TEXTURE2D_LOD(_Control, sampler_Control, splatUV, 0);
		
		float mask = 0;
		
		#ifdef _Grass1
		float mask1 = splatControl.r;
		mask += mask1;
		density += _GrassDensity1*mask1;
		#endif

		#ifdef _Grass2
		float mask2 = splatControl.g;
		mask+= mask2;
		density += _GrassDensity2*mask2;
		#endif

		#ifdef _Grass3
		float mask3 = splatControl.b;
		mask+= mask3;
		density += _GrassDensity3*mask3;
		#endif

		#ifdef _Grass4
		float mask4 = splatControl.a;
		mask+= mask4;
		density += _GrassDensity4*mask4;
		#endif

		return mask >= 0.1f;
	}

	TessellationFactors patchConstantFunc(InputPatch<TessellationControlPoint, 3> patch)
	{
		float density = 0;
		
		TessellationFactors f;
		
		if (needTessellation(patch[0],density) || needTessellation(patch[1],density) || needTessellation(patch[2],density))
		{
			f.edge[0] = tessellationEdgeFactor(patch[1], patch[2],density);
			f.edge[1] = tessellationEdgeFactor(patch[2], patch[0],density);
			f.edge[2] = tessellationEdgeFactor(patch[0], patch[1],density);
			f.inside = (f.edge[0] + f.edge[1] + f.edge[2]) / 3.0f;
		}
		else
		{
			f.edge[0] = 1;
			f.edge[1] = 1;
			f.edge[2] = 1;
			f.inside = 1;
		}
		return f;
	}

	//将顶点从重心空间转换到模型空间，插入顶点属性创建新的顶点
	[domain("tri")]
	vertexOutputGrass domain_Grass(TessellationFactors factors, OutputPatch<TessellationControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
	{
		TessellationControlPoint i;

		#define INTERPOLATE(fieldname) i.fieldname = \
			patch[0].fieldname * barycentricCoordinates.x + \
			patch[1].fieldname * barycentricCoordinates.y + \
			patch[2].fieldname * barycentricCoordinates.z;

		INTERPOLATE(positionOS)
		INTERPOLATE(normalOS)
		INTERPOLATE(tangentOS)
		INTERPOLATE(texcoord);
		return vert_Grass_Output(i);
	}

	struct geoOutputGrass
	{
	    float4 pos : SV_POSITION;
		float2 uv : TEXCOORD0;
		float3 normal : TEXCOORD1;
		float4 shadowCoord : TEXCOORD2;
		float3 posWS : TEXCOORD3;
		float2 texcoord : TEXCOORD4;
		half3 TopColor : TEXCOORD5;
		half3 BottomColor : TEXCOORD6;
	};

	struct AppendColor
	{
		half3 TopColor;
		half3 BottomColor;
	};

	geoOutputGrass append (float3 pos, float width, float height, float forward, float2 uv_Grass, float2 texcoord, float3x3 transformMatrix, AppendColor appendColor)
	{
	    geoOutputGrass o;
	    float3 tangentPoint = float3(width,forward,height);
	    float3 localPos = pos + mul(transformMatrix,tangentPoint); 
	    
	    float3 positionWS = TransformObjectToWorld(localPos);
		
		//交互草
		float3 tangentNormal = normalize(float3(0, 1, forward));
		float3 localNormal = mul(transformMatrix, tangentNormal);
		o.normal = normalize(TransformObjectToWorldNormal(localNormal));
		
		for (int i = 0; i<8; i++)
		{
			float dis = distance(_interactiveCharacterPos[i],positionWS);
			float pushDown = saturate((1-dis/_PushRadius)*uv_Grass.y*_Strength);
			float3 direction = normalize(positionWS -_interactiveCharacterPos[i]);
			direction.y *= 0.5;//减弱y方向影响
			positionWS.xyz += direction*pushDown;
			o.normal = normalize(o.normal+direction*pushDown);
		}
		localPos = TransformWorldToObject(positionWS);

		localPos = TransformWorldToObject(positionWS);
		
		o.pos = TransformObjectToHClip(localPos);
		o.uv = uv_Grass;
	    o.shadowCoord = TransformWorldToShadowCoord(positionWS);
	    o.posWS = positionWS;
		o.texcoord = texcoord;
		o.TopColor = appendColor.TopColor+(rand(pos)*2-1)*_ColorRandom;
		o.BottomColor = appendColor.BottomColor;
		
	    return o;
	}

	[maxvertexcount(BLADE_SEGMENTS * 2 + 1)]
	void geo_Grass(triangle vertexOutputGrass p[3] : SV_POSITION, inout TriangleStream<geoOutputGrass> triStream)
	{
	    float2 controlMap_UV = (p[1].uv * (_Control_TexelSize.zw - 1.0f) + 0.5f) * _Control_TexelSize.xy;
		
	    half4 controlMap = SAMPLE_TEXTURE2D_LOD(_Control,sampler_Control,controlMap_UV,0);
		float mask = 0;

		float3 pos = p[1].pos.xyz;
		float3 nDir = p[1].normal.xyz;
		float3 tDir = p[1].tangent.xyz;
		float3 bDir = cross(nDir,tDir)*p[1].tangent.w;

		float mask1 = controlMap.r;
		float mask2 = controlMap.g;
		float mask3 = controlMap.b;
		float mask4 = controlMap.a;

		float height = (rand(pos.zyx) * 2.0f - 1.0f) * _BladeHeightRandom;
		float width = (rand(pos.xzy) * 2.0f - 1.0f) * _BladeWidthRandom;
		
		float forward = rand(pos.yyz) * _BladeForward;

		AppendColor appendColor;
		appendColor.BottomColor = half3(0,0,0);
		appendColor.TopColor = half3(0,0,0);
		
		#ifdef _Grass1
		mask += mask1;
		height += _BladeHeight1*mask1;
		width += _BladeWidth1*mask1;
		appendColor.TopColor += _TopColor1.rgb*mask1;
		appendColor.BottomColor += _BottomColor1.rgb*mask1;
		#endif

	    #ifdef _Grass2
		mask += mask2;
		height += _BladeHeight2*mask2;
		width += _BladeWidth2*mask2;
		appendColor.TopColor += _TopColor2.rgb*mask2;
		appendColor.BottomColor += _BottomColor2.rgb*mask2;
	    #endif

		#ifdef _Grass3
		mask += mask3;
		height += _BladeHeight3*mask3;
		width += _BladeWidth3*mask3;
		appendColor.TopColor += _TopColor3.rgb*mask3;
		appendColor.BottomColor += _BottomColor3.rgb*mask3;
		#endif

		#ifdef _Grass4
		mask += mask4;
		height += _BladeHeight4*mask4;
		width += _BladeWidth4*mask4;
		appendColor.TopColor += _TopColor4.rgb*mask4;
		appendColor.BottomColor += _BottomColor4.rgb*mask4;
		#endif
		
	    if (mask<0.9)
	    {
	        return;
	    }
		
	    float3x3 TBN = float3x3(
	        tDir.x, bDir.x, nDir.x,
	        tDir.y, bDir.y, nDir.y,
	        tDir.z, bDir.z, nDir.z);
		

	    float2 uv = pos.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;
	    float windStrength = _WindStrength+0.001f;
	    float2 windSample = (SAMPLE_TEXTURE2D_LOD(_WindDistortionMap,sampler_WindDistortionMap, uv,0).xy * 2 - 1) * windStrength;
	    
	    float3 wind = normalize(float3(windSample.x,0,windSample.y));
	    float3x3 windRotation = AngleAxis3x3(PI * windSample.x, wind);

	    float3x3 facingRotationMatrix = AngleAxis3x3(rand(pos) * TWO_PI, float3(0, 0, 1));

	    float3x3 bendRotationMatrix = AngleAxis3x3(rand(pos.zzx) * _BendRotationRandom * PI * 0.5, float3(-1, 0, 0));
	    
	    float3x3 transformationMatrix = mul(mul(mul(TBN, windRotation), facingRotationMatrix), bendRotationMatrix);
	    //float3x3 transformationMatrix = mul(mul(TBN, facingRotationMatrix), bendRotationMatrix);
	    float3x3 transformationMatrixFacing = mul(TBN, facingRotationMatrix);

	    for (int i = 0; i < BLADE_SEGMENTS; i++)
		{
			float t = i / (float)BLADE_SEGMENTS;

	        float segmentHeight = height * t;
			float segmentWidth = width * (1 - t);
	        float segmentForward = pow(t, _BladeCurve) * forward;

	        float3x3 transformMatrix = i == 0 ? transformationMatrixFacing : transformationMatrix;

			triStream.Append(append(pos, segmentWidth, segmentHeight, segmentForward, float2(1, t), p[1].uv,transformMatrix,appendColor));
			triStream.Append(append(pos, -segmentWidth, segmentHeight, segmentForward, float2(0, t), p[1].uv,transformMatrix,appendColor));
		}
	    
	    triStream.Append(append(pos,0,height,forward,float2(0.5,1),p[1].uv,transformationMatrix,appendColor));
	}

	half4 frag_Grass (geoOutputGrass i, half facing : VFACE) : SV_TARGET
   {
   	half weight;
   	half4 mixedDiffuse;
   	half4 defaultSmoothness;
   	float4 mainUV;
   	float4 uvSplat01;
   	float4 uvSplat23;
   	
   	mainUV.xy = i.texcoord;
   	mainUV.zw = i.texcoord * unity_LightmapST.xy + unity_LightmapST.zw;
   	uvSplat01.xy = TRANSFORM_TEX(i.texcoord, _Splat0);
   	uvSplat01.zw = TRANSFORM_TEX(i.texcoord, _Splat1);
   	uvSplat23.xy = TRANSFORM_TEX(i.texcoord, _Splat2);
   	uvSplat23.zw = TRANSFORM_TEX(i.texcoord, _Splat3);
   	
   	float2 splatUV = (mainUV.xy * (_Control_TexelSize.zw - 1.0f) + 0.5f) * _Control_TexelSize.xy;
   	half4 splatControl = SAMPLE_TEXTURE2D(_Control, sampler_Control, splatUV);
   	half3 normalTS = half3(0.0h, 0.0h, 1.0h);
   	SplatmapMix(mainUV, uvSplat01, uvSplat23,splatControl,
   		weight, mixedDiffuse, defaultSmoothness, normalTS);
   	half3 albedo = mixedDiffuse.rgb;
            
	Light mainLight = GetMainLight(i.shadowCoord);

   	float mask1 = splatControl.r;
   	float mask2 = splatControl.g;
   	float mask3 = splatControl.b;
   	float mask4 = splatControl.a;

   	
   	half3 color = lerp(i.BottomColor,i.TopColor,i.uv.y);
   	half3 colorTint = half3(0,0,0);
   	
   	#ifdef _Grass1
   	colorTint += _GrassColorTint1.rgb*mask1;
   	#endif
   	
   	#ifdef _Grass2
   	colorTint += _GrassColorTint2.rgb*mask2;
   	#endif
   	
   	#ifdef _Grass3
   	colorTint += _GrassColorTint3.rgb*mask3;
   	#endif
   	
   	#ifdef _Grass4
   	colorTint += _GrassColorTint4.rgb*mask4;
   	#endif
   	
	color.rgb = lerp(color.rgb,albedo,_Lerp)*colorTint;

   	float3 nDir = facing > 0 ? i.normal : -i.normal;
   	float dayMask = smoothstep(0,1,_MainLightPosition.y);
   	float nightMask = smoothstep(0,1,-_MainLightPosition.y);
   	float3 lDir =_MainLightPosition*dayMask + (-_MainLightPosition*nightMask);
   	float nDotl = dot(nDir,lDir);
   	
   	float halfLambert = saturate(nDotl*0.5+0.5+_TranslucentGain);

   	float shadow = saturate(mainLight.shadowAttenuation+0.5);

   	half3 FinalRGB = color*halfLambert*shadow;
   	
	half4 result = half4(FinalRGB,1.0);
            
	return result;
   }