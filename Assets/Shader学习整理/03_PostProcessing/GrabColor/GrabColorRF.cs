using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

public class GrabColorRF : ScriptableRendererFeature
{
    [System.Serializable]
     public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    }
     
    class GrabColorRenderPass : ScriptableRenderPass
    {
        //定义一个 ProfilingSampler 方便设置在FrameDebugger里查看
        private const string ProfilerTag = "GrabColorRenderPass";
        private ProfilingSampler m_ProfilingSampler = new(ProfilerTag);
        

        private RTHandle cameraColorRTHandle;//可以理解为GameView_RenderTarget的句柄
        private RTHandle tempRTHandle;

        //自定义Pass的构造函数(用于传参)
        public GrabColorRenderPass(Settings settings)
        {
            renderPassEvent = settings.renderPassEvent; //传入设置的渲染事件顺序(renderPassEvent在基类ScriptableRenderPass中)
        }

        public void GetTempRT(ref RTHandle temp, in RenderingData data)
        {
            RenderTextureDescriptor desc = data.cameraData.cameraTargetDescriptor;
            desc.depthBufferBits = 0; //这步很重要！！！
            RenderingUtils.ReAllocateIfNeeded(ref temp, desc);//使用该函数申请一张与相机大小一致的TempRT;
        }

        public void Setup(RTHandle cameraColor)
        {
            cameraColorRTHandle = cameraColor;
        }
        
        //此方法由渲染器在渲染相机之前调用
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            ConfigureInput(ScriptableRenderPassInput.Color); //确认传入的参数类型为Color
            GetTempRT(ref tempRTHandle,renderingData);//获取与摄像机大小一致的临时RT
            ConfigureTarget(tempRTHandle);//确认传入的目标为cameraColorRT
            ConfigureClear(ClearFlag.All, Color.black);
        }
        
        //执行传递。这是自定义渲染发生的地方
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            
            CommandBuffer cmd = CommandBufferPool.Get(ProfilerTag);//获得一个为ProfilerTag的CommandBuffer
            
            var stack = VolumeManager.instance.stack;//获取Volume的栈
            
            //性能分析器(自带隐式垃圾回收),之后可以在FrameDebugger中查看
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                context.ExecuteCommandBuffer(cmd);//执行CommandBuffer
                cmd.Clear();
                Blitter.BlitCameraTexture(cmd,cameraColorRTHandle,tempRTHandle);
                cmd.SetGlobalTexture("_GrabColorTex",tempRTHandle);
            }
            
            context.ExecuteCommandBuffer(cmd);//执行CommandBuffer
            cmd.Clear();
            CommandBufferPool.Release(cmd);//释放CommandBuffer
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
    private GrabColorRenderPass _grabColorRenderPass;
    public Settings settings = new Settings();
    
    //初始化时调用
    public override void Create()
    {
        _grabColorRenderPass = new GrabColorRenderPass(settings);
    }
    
    //每帧调用,将pass添加进流程
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(_grabColorRenderPass);
    }

    //每帧调用,渲染目标初始化后的回调。这允许在创建并准备好目标后从渲染器访问目标
    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        _grabColorRenderPass.Setup(renderer.cameraColorTargetHandle);//可以理解为传入GameView_RenderTarget的句柄和相机渲染数据（相机渲染数据用于创建TempRT）
        
    }
    
    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        _grabColorRenderPass.OnDispose();
        
    }
}


