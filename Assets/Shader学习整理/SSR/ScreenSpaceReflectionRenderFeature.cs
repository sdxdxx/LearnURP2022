using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ScreenSpaceReflectionRenderFeature : ScriptableRendererFeature
{
    public enum ScreenSpaceReflectionType
    {
        Simple_ViewSpace = 1,
        BinarySearch_ViewSpace,
        BinarySearch_Jitter_ViewSpace,
        Efficient_ScreenSpace,
        Efficient_ScreenSpace_Jitter,
        HIZ_ViewSpace
    }
    
    [System.Serializable]
     public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    }
     
     //自定义的Pass
    class CustomRenderPass : ScriptableRenderPass
    {
        private RenderingData renderingData;
        
        //定义一个 ProfilerTag 方便设置在FrameDebugger里查看
        private const string ProfilerTag = "ScreenSpaceReflection";
        
        private Material material_HIZ;
        private Material material;
        
        private ScreenSpaceReflectionVolume screenSpaceReflectionVolume;

        private RTHandle cameraColorRTHandle;//可以理解为GameView_RenderTarget的句柄
        private RTHandle tempRTHandle;
        private RTHandle tempRTHandle1;
        private RTHandle tempRTHandle2;
        private RTHandle tempRTHandle3;
        private RTHandle tempRTHandle4;
        private RTHandle tempRTHandle5;
        private Vector4[] sourceSize = new Vector4[6];

        //自定义Pass的构造函数(用于传参)
        public CustomRenderPass(RenderPassEvent evt)
        {
            renderPassEvent = evt; //传入设置的渲染事件顺序(renderPassEvent在基类ScriptableRenderPass中)
            
            //根据传入的Shader创建material;
            Shader shader= Shader.Find("URP/PostProcessing/ScreenSpaceReflection");
            Shader shader_HIZ = Shader.Find("URP/PostProcessing/HIZ");
            material_HIZ = CoreUtils.CreateEngineMaterial(shader_HIZ);
            material = CoreUtils.CreateEngineMaterial(shader);
            
        }

        public void GetTempRT(ref RTHandle temp, in RenderingData data, int downSample)
        {
            RenderTextureDescriptor desc = data.cameraData.cameraTargetDescriptor;
            desc.depthBufferBits = 0; //这步很重要！！！
            desc.height = desc.height / downSample;
            desc.width = desc.width / downSample;
            RenderingUtils.ReAllocateIfNeeded(ref temp, desc);//使用该函数申请一张与相机大小一致的TempRT;
        }

        public void Setup(RTHandle cameraColor, RenderingData data)
        {
            cameraColorRTHandle = cameraColor;
            renderingData = data;
        }
        
        //此方法由渲染器在渲染相机之前调用
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            ConfigureInput(ScriptableRenderPassInput.Color); //确认传入的参数类型为Color
            ConfigureTarget(cameraColorRTHandle);//确认传入的目标为cameraColorRT
            
            
            GetTempRT(ref tempRTHandle,this.renderingData,1);//获取与摄像机大小一致的临时RT
            GetTempRT(ref tempRTHandle1,this.renderingData,2);//获取与摄像机大小1/4的临时RT
            GetTempRT(ref tempRTHandle2,this.renderingData,4);//获取与摄像机大小1/16的临时RT
            GetTempRT(ref tempRTHandle3,this.renderingData,8);//获取与摄像机大小1/64的临时RT
            GetTempRT(ref tempRTHandle4,this.renderingData,16);//获取与摄像机大小1/256的临时RT
            GetTempRT(ref tempRTHandle5,this.renderingData,32);//获取与摄像机大小1/1024的临时RT
            
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
            
            float width = desc.width; float height = desc.height;
            for (int i = 0; i < sourceSize.Length; i++)
            {
                float realWidth = (int)width;
                float realHeight= (int)height;
                sourceSize[i] = new Vector4(realWidth, realHeight, 1.0f/realWidth, 1.0f/realHeight);
                width *= 0.5f; height *= 0.5f;
            }
            
        }
        
        //执行传递。这是自定义渲染发生的地方
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var stack = VolumeManager.instance.stack;//获取Volume的栈
            screenSpaceReflectionVolume = stack.GetComponent<ScreenSpaceReflectionVolume>();//从栈中获取到Volume
            var shaderType = (ScreenSpaceReflectionType)screenSpaceReflectionVolume.ScreenSpaceReflectionMode.value;
            
            material.DisableKeyword("SIMPLE_VS");
            material.DisableKeyword("BINARY_SEARCH_VS");
            material.DisableKeyword("BINARY_SEARCH_JITTER_VS");
            material.DisableKeyword("EFFICIENT_SS");
            material.DisableKeyword("EFFICIENT_JITTER_SS");
            material.DisableKeyword("HIZ_VS");
            
            switch (shaderType)
            {
                case ScreenSpaceReflectionType.Simple_ViewSpace:
                    material.EnableKeyword("SIMPLE_VS");
                    break;
                
                case ScreenSpaceReflectionType.BinarySearch_ViewSpace:
                    material.EnableKeyword("BINARY_SEARCH_VS");
                    break;
                
                case ScreenSpaceReflectionType.BinarySearch_Jitter_ViewSpace:
                    material.EnableKeyword("BINARY_SEARCH_JITTER_VS");
                    break;
                
                case ScreenSpaceReflectionType.Efficient_ScreenSpace:
                    material.EnableKeyword("EFFICIENT_SS");
                    break;
                
                case ScreenSpaceReflectionType.Efficient_ScreenSpace_Jitter:
                    material.EnableKeyword("EFFICIENT_JITTER_SS");
                    break;
                
                case ScreenSpaceReflectionType.HIZ_ViewSpace:
                    material.EnableKeyword("HIZ_VS");
                    break;
            }
            //材质参数设置
            material.SetColor("_BaseColor", screenSpaceReflectionVolume.ColorChange.value);
            
            //Simple
            material.SetFloat("_StepLength",screenSpaceReflectionVolume.StepLength.value);
            material.SetFloat("_Thickness",screenSpaceReflectionVolume.Thickness.value);
            
            //BinarySearch
            material.SetFloat("_MaxStepLength",screenSpaceReflectionVolume.MaxStepLength.value);
            material.SetFloat("_MinDistance",screenSpaceReflectionVolume.MinDistance.value);
            
            //Efficient
            material.SetFloat("_MaxReflectLength",screenSpaceReflectionVolume.MaxReflectLength.value);
            material.SetInt("_DeltaPixel",screenSpaceReflectionVolume.DeltaPixel.value);
            
            //Jitter Dither
            material.SetFloat("_DitherIntensity",screenSpaceReflectionVolume.DitherIntensity.value);
            
            if (screenSpaceReflectionVolume.EnableReflection.value)
            {
                CommandBuffer cmd = CommandBufferPool.Get(ProfilerTag);//获得一个为ProfilerTag的CommandBuffer
                
                //性能分析器(自带隐式垃圾回收),之后可以在FrameDebugger中查看
                using (new ProfilingScope(cmd, new ProfilingSampler("ScreenSpaceReflection_Hiz")))
                {
                    if (shaderType == ScreenSpaceReflectionType.HIZ_ViewSpace)
                    {
                        Blitter.BlitCameraTexture(cmd,cameraColorRTHandle,tempRTHandle,material_HIZ,0);//采样原深度图
                        material_HIZ.SetVector("_SourceSize1",sourceSize[1]);
                        Blitter.BlitCameraTexture(cmd,tempRTHandle,tempRTHandle1,material_HIZ,1);
                        material_HIZ.SetVector("_SourceSize2",sourceSize[2]);
                        Blitter.BlitCameraTexture(cmd,tempRTHandle1,tempRTHandle2,material_HIZ,2);
                        material_HIZ.SetVector("_SourceSize3",sourceSize[3]);
                        Blitter.BlitCameraTexture(cmd,tempRTHandle2,tempRTHandle3,material_HIZ,3);
                        material_HIZ.SetVector("_SourceSize4",sourceSize[4]);
                        Blitter.BlitCameraTexture(cmd,tempRTHandle3,tempRTHandle4,material_HIZ,4);
                        material_HIZ.SetVector("_SourceSize5",sourceSize[5]);
                        Blitter.BlitCameraTexture(cmd,tempRTHandle4,tempRTHandle5,material_HIZ,5);
                        
                        
                        material.SetTexture("_CameraDepthTexture_MipLevel_2",tempRTHandle1);
                        material.SetTexture("_CameraDepthTexture_MipLevel_3",tempRTHandle2);
                        material.SetTexture("_CameraDepthTexture_MipLevel_4",tempRTHandle3);
                        material.SetTexture("_CameraDepthTexture_MipLevel_5",tempRTHandle4);
                        material.SetTexture("_CameraDepthTexture_MipLevel_6",tempRTHandle5);
                    }
                }

                using (new ProfilingScope(cmd, new ProfilingSampler("ScreenSpaceReflection_Main")))
                {
                    Blitter.BlitCameraTexture(cmd,cameraColorRTHandle,tempRTHandle,material,0);//写入渲染命令进CommandBuffer
                    if (screenSpaceReflectionVolume.ShowReflectionTexture.value)
                    {
                        Blitter.BlitCameraTexture(cmd,tempRTHandle,cameraColorRTHandle);
                    }
                    else
                    {
                        Shader.SetGlobalTexture("_ScreenSpaceReflectionTexture",tempRTHandle);
                    }
                }
                
                context.ExecuteCommandBuffer(cmd);//执行CommandBuffer
                
                cmd.Clear();
                CommandBufferPool.Release(cmd);//释放CommandBuffer
            }
        }
        
        //在完成渲染相机时调用
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            
        }
        
        public void OnDispose() 
        {
            //如果tempRTHandle没被释放的话，会被释放
            tempRTHandle?.Release();
            tempRTHandle1?.Release();
            tempRTHandle2?.Release();
            tempRTHandle3?.Release();
            tempRTHandle4?.Release();
            tempRTHandle5?.Release();
        }
    }

    //-------------------------------------------------------------------------------------------------------
    private CustomRenderPass m_ScriptablePass;
    public Settings settings = new Settings();
    
    //初始化时调用
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass(settings.renderPassEvent);
    }
    
    //每帧调用,将pass添加进流程
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }

    //每帧调用,渲染目标初始化后的回调。这允许在创建并准备好目标后从渲染器访问目标
    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        m_ScriptablePass.Setup(renderer.cameraColorTargetHandle,renderingData);//可以理解为传入GameView_RenderTarget的句柄和相机渲染数据（相机渲染数据用于创建TempRT）
    }
    
    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        m_ScriptablePass.OnDispose();
    }
}


