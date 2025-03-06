using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

public class PixelizeObjectPass : ScriptableRendererFeature
{
    [System.Serializable]
     public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingSkybox;
        public LayerMask layerMask;
    }
     
     //自定义的Pass
    class CustomRenderPass : ScriptableRenderPass
    {
        private RenderingData renderingData;
        FilteringSettings filtering;
        private List<ShaderTagId> shaderTagsList = new List<ShaderTagId>();
        
        //定义一个 ProfilingSampler 方便设置在FrameDebugger里查看
        private const string ProfilerTag = "PixelizeObjectPass";
        private ProfilingSampler m_ProfilingSampler = new("PixelizeObjectPass");
        
        private RTHandle cameraColorRTHandle;//可以理解为GameView_RenderTarget的句柄
        private RTHandle depthTarget;
        private RTHandle tempRTHandle;
        private RTHandle maskRTHandle;

        //自定义Pass的构造函数(用于传参)
        public CustomRenderPass(Settings settings)
        {
            filtering = new FilteringSettings(RenderQueueRange.all, settings.layerMask);//设置过滤器
            shaderTagsList.Add(new ShaderTagId("PixelizePass"));
            renderPassEvent = settings.renderPassEvent+2; //传入设置的渲染事件顺序(renderPassEvent在基类ScriptableRenderPass中)
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
            depthTarget = renderingData.cameraData.renderer.cameraDepthTargetHandle;
            ConfigureInput(ScriptableRenderPassInput.Color); //确认传入的参数类型为Color
        }
        
        //执行传递。这是自定义渲染发生的地方
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (this.renderingData.cameraData.cameraType != CameraType.Game)
            {
                return;
            }
            
            CommandBuffer cmd = CommandBufferPool.Get(ProfilerTag);//获得一个为ProfilerTag的CommandBuffer
            
            //性能分析器(自带隐式垃圾回收),之后可以在FrameDebugger中查看
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                // Ensure we flush our command-buffer before we render...
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                
                SortingCriteria sortingCriteria = SortingCriteria.CommonOpaque;
                var draw = CreateDrawingSettings(shaderTagsList, ref renderingData, sortingCriteria);
                context.DrawRenderers(renderingData.cullResults, ref draw, ref filtering);
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
            maskRTHandle?.Release();
            tempRTHandle?.Release();
        }
    }

    //-------------------------------------------------------------------------------------------------------
    private CustomRenderPass m_ScriptablePass;
    public Settings settings = new Settings();
    
    //初始化时调用
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass(settings);
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


