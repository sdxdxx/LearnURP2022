Shader "URP/ReflectCube" //URP路径名
{
     //面板属性
    Properties
    {
	      _ReflectBlur("反射模糊", Range( 0 , 1)) = 0
    }
        SubShader
        {
			//渲染类型为URP
           Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline"}
			//多距离级别
            LOD 100 


		 Pass
        {

            HLSLPROGRAM  //URP 程序块开始

			//顶点程序片段 vert
			#pragma vertex vert

			//表面程序片段 frag
            #pragma fragment frag




			//URP函数库
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			

			CBUFFER_START(UnityPerMaterial) //变量引入开始

			float _ReflectBlur;

            CBUFFER_END //变量引入结束



			//定义模型原始数据结构
            struct VertexInput          
            {
				//获取物体空间顶点坐标
                float4 positionOS : POSITION; 

				//获取模型UV坐标
                float2 uv : TEXCOORD0;

					//模型法线
				float4 normalOS  : NORMAL;
            };


			//定义顶点程序片段与表i面程序片段的传递数据结构
            struct VertexOutput 
            {
			   //物体视角空间坐标
                float4 positionCS : SV_POSITION; 
				
				//UV坐标
                float2 uv : TEXCOORD0;

				//世界空间顶点
				float3 positionWS :  TEXCOORD1;
				//世界空间法线
				float3 normalWS : TEXCOORD2;
            };

			
				//顶点程序片段
                VertexOutput vert(VertexInput v)
                {
				   //声明输出变量o
                    VertexOutput o;


					//输入物体空间顶点数据
					VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz);
					//获取裁切空间顶点
                    o.positionCS = positionInputs.positionCS;
					//获取世界空间顶点
					o.positionWS = positionInputs.positionWS;
					
					//输入物体空间法线数据
					VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normalOS.xyz);

					//获取世界空间法线
					o.normalWS = normalInputs.normalWS;

					//输出数据
                    return o;
                }

				//表面程序片段
                float4 frag(VertexOutput i): SV_Target 
                {
				//贴图法线转换为世界法线
				half3 normalWS = i.normalWS;
				//摄像机方向
				float3 viewDir = normalize(_WorldSpaceCameraPos.xyz-i.positionWS);
				//获取当前视角反射
				float3 reflectDirWS = reflect(-viewDir,normalWS);
				//读取反射探针贴图
				   float4 _CubeMapColor = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectDirWS,_ReflectBlur*8);
                	float3 iblSpecular = DecodeHDREnvironment(_CubeMapColor, unity_SpecCube0_HDR);

                	float4 result = float4(iblSpecular,1.0);

					//输出颜色
                    return  result;
                }

                ENDHLSL  //URP 程序块结束
            
        }
    }
}