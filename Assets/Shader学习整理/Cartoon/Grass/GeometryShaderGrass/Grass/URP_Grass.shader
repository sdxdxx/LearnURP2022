Shader "URP/Grass"
{
    Properties
    {
    	_DiffuseTex("DiffuseTex",2D) = "white"{}
    	_ControlMap("ControlMap",2D) = "white"{}
    	_Lerp("Lerp",Range(0,1)) = 0
    	
        [Header(Color)]
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _TopColor("TopColor",Color) = (0.1,1.0,0.1,1.0)
        _BottomColor("BottomColor",Color) = (0,0.5,0,1.0)
        
        [Header(WidthAndHeight)]
        _BladeWidth("Blade Width", Float) = 0.05
        _BladeWidthRandom("Blade Width Random", Float) = 0.02
        _BladeHeight("Blade Height", Float) = 0.5
        _BladeHeightRandom("Blade Height Random", Float) = 0.3
    	
    	[Header(Forward)]
    	_BladeForward("Blade Forward Amount", Float) = 0.38
		_BladeCurve("Blade Curvature Amount", Range(1, 4)) = 2
        
        [Header(Bend)]
        _BendRotationRandom("Bend Rotation Random", Range(0, 1)) = 0.2
        
    	[Header(Wind)]
    	_WindDistortionMap("Wind Distortion Map", 2D) = "white" {}
        _WindFrequency("Wind Frequency", Vector) = (0.05, 0.05, 0, 0)
    	_WindStrength("Wind Strength", Range(0,10)) = 1
    	
    	[Header(Density)]
    	[IntRange]_GrassDensity("Grass Density",Range(1,20)) = 1
    	
    	[Header(Gain)]
    	_TranslucentGain("Translucent Gain",Range(0,0.5)) = 0.3
    	
    	[Header(InteractiveGrass)]
    	//_PlayerPos("Player Position",Vector) = (0,0,0,0)
    	_PushRadius("Push Radius",float) = 0
    	_Strength("Strength",Range(0,5)) = 0
    	
    }
    
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        //解决深度引动模式Depth Priming Mode问题
        UsePass "Universal Render Pipeline/Unlit/DepthOnly"
        UsePass "Universal Render Pipeline/Unlit/DepthNormalsOnly"
    	
        HLSLINCLUDE
    	#define BLADE_SEGMENTS 4
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
    
        
        //----------贴图声明开始-----------
        TEXTURE2D(_DiffuseTex);
        SAMPLER(sampler_DiffuseTex);
        TEXTURE2D(_WindDistortionMap);
        SAMPLER(sampler_WindDistortionMap);
    	TEXTURE2D(_ControlMap);
        SAMPLER(sampler_ControlMap);
        //----------贴图声明结束-----------
        
        CBUFFER_START(UnityPerMaterial)
        //----------变量声明开始-----------

        float3 _PlayerPos;
        float _PushRadius;
        float _Strength;

    	float _Lerp;
    
        half4 _BaseColor;
        float4 _DiffuseTex_ST;
    	float4 _ControlMap_ST;
        float4 _ControlMap_TexelSize;
        half4 _TopColor;
        half4 _BottomColor;
        
        float _BladeHeight;
        float _BladeHeightRandom;	
        float _BladeWidth;
        float _BladeWidthRandom;

        float _BladeForward;
		float _BladeCurve;
        
        float  _BendRotationRandom;

        float4 _WindDistortionMap_ST;
        float2 _WindFrequency;
        float _WindStrength;

        int _GrassDensity;

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
        
        struct vertexInputGrass
        {
            float4 vertex : POSITION;
            float4 normal : NORMAL;
            float4 tangent : TANGENT;
            float2 uv : TEXCOORD0;
        };

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

        TessellationControlPoint vert_Grass(vertexInputGrass v)
         {
	         TessellationControlPoint p;
             p.positionOS= v.vertex;
             p.normalOS = v.normal.xyz;
             p.tangentOS= v.tangent;
         	p.texcoord = v.uv;
            return p;
        }

        vertexOutputGrass vert_Grass_Output (TessellationControlPoint v)
        {
            vertexOutputGrass o;
             o.pos = v.positionOS;
             o.normal = v.normalOS;
             o.tangent= v.tangentOS;
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
		float tessellationEdgeFactor(TessellationControlPoint vert0, TessellationControlPoint vert1)
		{
			float3 v0 = vert0.positionOS.xyz;
			float3 v1 = vert1.positionOS.xyz;
			float edgeLength = distance(v0, v1);

			//float2 vertexXZ = v0.xz;
			//float disVertexAndCamera = distance(vertexXZ, _WorldSpaceCameraPos.xz);
			//float tessClamp = clamp((1.0 - (disVertexAndCamera - 10) / (_GrassDistanceMax - _GrassDistanceMin)),0.5,1.0);
			
			return edgeLength * _GrassDensity;
		}
        
		//增加边缘的控制点，同时图元内部将会增加新的层
    		bool needTessellation(TessellationControlPoint v)
		{
			float3 posWS = TransformObjectToWorld(v.positionOS.xyz);
			float2 splatUV = posWS.xz*_ControlMap_ST.xy+_ControlMap_ST.zw;
			float splatControl = SAMPLE_TEXTURE2D_LOD(_ControlMap, sampler_ControlMap, splatUV, 0).x;

			return splatControl >= 0.1f;
		}
    
		TessellationFactors patchConstantFunc(InputPatch<TessellationControlPoint, 3> patch)
		{
			TessellationFactors f;
			
			if (needTessellation(patch[0]) || needTessellation(patch[1]) || needTessellation(patch[2]))
			{
				f.edge[0] = tessellationEdgeFactor(patch[1], patch[2]);
				f.edge[1] = tessellationEdgeFactor(patch[2], patch[0]);
				f.edge[2] = tessellationEdgeFactor(patch[0], patch[1]);
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
			float4 shadowCoord : TEXCOORD1;
			float3 posWS : TEXCOORD2;
			float3 normal : TEXCOORD3;
        };

        geoOutputGrass append (float3 pos, float width, float height, float forward, float2 uv, float3x3 transformMatrix)
        {
            geoOutputGrass o;
            float3 tangentPoint = float3(width,forward,height);
            float3 localPos = pos + mul(transformMatrix,tangentPoint);
        	float3 positionWS = TransformObjectToWorld(localPos);
        	
        	//交互草
        	float dis = distance(_PlayerPos,positionWS);
        	float pushDown = saturate((1-dis/_PushRadius)*uv.y*_Strength);
        	float3 direction = normalize(positionWS -_PlayerPos);
        	direction.y *= 0.5;//减弱y方向影响
        	positionWS.xyz += direction*pushDown;

        	localPos = TransformWorldToObject(positionWS);
        	o.pos = TransformObjectToHClip(localPos);
            o.uv = uv;
            o.shadowCoord = TransformWorldToShadowCoord(positionWS);
            o.posWS = positionWS;

        	float3 tangentNormal = normalize(float3(0, -1, forward));
			float3 localNormal = mul(transformMatrix, tangentNormal);
			o.normal = normalize(TransformObjectToWorldNormal(localNormal)+direction*pushDown);
        	
            return o;
        }
        
        [maxvertexcount(BLADE_SEGMENTS * 2 + 1)]
        void geo_Grass(triangle vertexOutputGrass p[3] : SV_POSITION, inout TriangleStream<geoOutputGrass> triStream)
        {
            float3 posWS = TransformObjectToWorld(p[1].pos.xyz);
            float2 controlMap_UV = posWS.xz*_ControlMap_ST.xy+_ControlMap_ST.zw;
            half4 controlMap = SAMPLE_TEXTURE2D_LOD(_ControlMap,sampler_ControlMap,controlMap_UV,0);
            
            if (controlMap.x<0.1)
            {
                return;
            }
            
            float3 pos = p[1].pos.xyz;
            float3 nDir = p[1].normal.xyz;
            float3 tDir = p[1].tangent.xyz;
            float3 bDir = cross(nDir,tDir)*p[1].tangent.w;

            float height = (rand(pos.zyx) * 2.0f - 1.0f) * _BladeHeightRandom + _BladeHeight;
            float width = (rand(pos.xzy) * 2.0f - 1.0f) * _BladeWidthRandom + _BladeWidth;
            float forward = rand(pos.yyz) * _BladeForward;

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
            float3x3 transformationMatrixFacing = mul(TBN, facingRotationMatrix);

            for (int i = 0; i < BLADE_SEGMENTS; i++)
			{
				float t = i / (float)BLADE_SEGMENTS;

            	float segmentHeight = height * t;
				float segmentWidth = width * (1 - t);
            	float segmentForward = pow(t, _BladeCurve) * forward;

            	float3x3 transformMatrix = i == 0 ? transformationMatrixFacing : transformationMatrix;

				triStream.Append(append(pos, segmentWidth, segmentHeight, segmentForward, float2(1, t), transformMatrix));
				triStream.Append(append(pos, -segmentWidth, segmentHeight, segmentForward, float2(0, t), transformMatrix));
			}
            
            triStream.Append(append(pos,0,height,forward,float2(0.5,1),transformationMatrix));
        }
    	
    	ENDHLSL
        
        pass
        {
        	Name "GrassPass"
	        Cull Off
        	
            HLSLPROGRAM
            
            #pragma vertex vert_Grass
            #pragma hull hull_Grass
            #pragma domain domain_Grass
            #pragma geometry geo_Grass
            #pragma fragment frag_Grass
            
            #pragma multi_compile  _MAIN_LIGHT_SHADOWS
			#pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile  _SHADOWS_SOFT

            #pragma require geometry
    		#pragma require tessellation tessHW

            #pragma target 4.6
            
            
            half4 frag_Grass (geoOutputGrass i, half facing : VFACE) : SV_TARGET
            {
            	float2 albedo_UV = i.posWS.xz*_DiffuseTex_ST.xy+_DiffuseTex_ST.zw;
            	half4 albedo = SAMPLE_TEXTURE2D(_DiffuseTex,sampler_DiffuseTex,albedo_UV)*_BaseColor;
            	
            	Light mainLight = GetMainLight(i.shadowCoord);
				
                half4 color = lerp(_BottomColor,_TopColor,i.uv.y);
            	color = lerp(color,albedo,_Lerp);

            	float3 nDir = facing > 0 ? i.normal : -i.normal;
   				float dayMask = smoothstep(0,1,_MainLightPosition.y);
   				float nightMask = smoothstep(0,1,-_MainLightPosition.y);
   				float3 lDir =_MainLightPosition.xyz*dayMask + (-_MainLightPosition.xyz*nightMask);
   				float nDotl = dot(nDir,lDir);
   				
   				float halfLambert = saturate(nDotl*0.5+0.5+_TranslucentGain);

   				float shadow = saturate(mainLight.shadowAttenuation+0.5);

   				half3 FinalRGB = color.rgb*halfLambert*shadow;

            	half4 result = half4(FinalRGB,1.0);
            	
                return result;
            }
            
            ENDHLSL
        }
    	
    	// shadow casting pass with empty fragment
		Pass
		{
		Name "GrassShadowCaster"
		Tags{ "LightMode" = "ShadowCaster" }

		ZWrite On
		ZTest LEqual

		HLSLPROGRAM

		 #pragma vertex vert_Grass
		#pragma hull hull_Grass
		#pragma domain domain_Grass
		#pragma geometry geo_Grass
		#pragma fragment frag

		#define SHADERPASS_SHADOWCASTER

		#pragma shader_feature_local _ DISTANCE_DETAIL
		#pragma require geometry
		#pragma require tessellation tessHW

		#pragma target 4.6

		half4 frag(geoOutputGrass input) : SV_TARGET
		{
			return 1;
		 }

		ENDHLSL
		}


    }
}