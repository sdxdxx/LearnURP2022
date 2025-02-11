using System;
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
        Efficient_ScreenSpace
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
        
        //定义一个 ProfilingSampler 方便设置在FrameDebugger里查看
        private const string ProfilerTag = "ScreenSpaceReflection";
        private ProfilingSampler m_ProfilingSampler = new(ProfilerTag);
        
        private Material material;
        private ScreenSpaceReflectionVolume screenSpaceReflectionVolume;

        private RTHandle cameraColorRTHandle;//可以理解为GameView_RenderTarget的句柄
        private RTHandle tempRTHandle;
        private RTHandle tempRTHandle2;

        //自定义Pass的构造函数(用于传参)
        public CustomRenderPass(RenderPassEvent evt)
        {
            renderPassEvent = evt; //传入设置的渲染事件顺序(renderPassEvent在基类ScriptableRenderPass中)

            Shader shader;
            shader= Shader.Find("URP/PostProcessing/ScreenSpaceReflection");
            material = CoreUtils.CreateEngineMaterial(shader);//根据传入的Shader创建material;
        }

        public void GetTempRT(ref RTHandle temp, in RenderingData data)
        {
            RenderTextureDescriptor desc = data.cameraData.cameraTargetDescriptor;
            desc.depthBufferBits = 0; //这步很重要！！！
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
            
            GetTempRT(ref tempRTHandle,this.renderingData);//获取与摄像机大小一致的临时RT
            GetTempRT(ref tempRTHandle2,this.renderingData);//获取与摄像机大小一致的临时RT
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
            
            if (screenSpaceReflectionVolume.EnableReflection.value)
            {
                CommandBuffer cmd = CommandBufferPool.Get(ProfilerTag);//获得一个为ProfilerTag的CommandBuffer
            
                //性能分析器(自带隐式垃圾回收),之后可以在FrameDebugger中查看
                using (new ProfilingScope(cmd, m_ProfilingSampler))
                {
                    Blitter.BlitCameraTexture(cmd,cameraColorRTHandle,tempRTHandle);
                    Blitter.BlitCameraTexture(cmd,tempRTHandle,tempRTHandle2,material,0);//写入渲染命令进CommandBuffer
                    if (screenSpaceReflectionVolume.ShowReflectionTexture.value)
                    {
                        Blitter.BlitCameraTexture(cmd,tempRTHandle2,cameraColorRTHandle);
                    }
                    else
                    {
                        Shader.SetGlobalTexture("_ScreenSpaceReflectionTexture",tempRTHandle2);
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
            tempRTHandle?.Release();//如果tempRTHandle没被释放的话，会被释放
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


