using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

public class PixelizeObject : ScriptableRendererFeature
{
    [System.Serializable]
     public class Settings
    {
        public LayerMask layerMask;
    }
     private static readonly RenderPassEvent pixelizeObjectClearCartoonRenderPassEvent = RenderPassEvent.AfterRenderingTransparents;
     private static readonly RenderPassEvent pixelizeObjectRenderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
     private static readonly RenderPassEvent clearObjectRenderPassEvent = RenderPassEvent.AfterRenderingTransparents;
     
     //ClearObjectGrabPass
    class ClearBackGroundObjectGrabPass : ScriptableRenderPass
    {
        private RenderingData renderingData;
        
        //定义一个 ProfilingSampler 方便设置在FrameDebugger里查看
        private const string ProfilerTag = "ClearBackGroundObjectGrabPass";
        private ProfilingSampler m_ProfilingSampler = new("ClearBackGroundObjectGrabPass");
        
        private RTHandle cameraColorRTHandle;
        private RTHandle depthTarget;
        
        private RTHandle tempRTHandle;

        //自定义Pass的构造函数(用于传参)
        public ClearBackGroundObjectGrabPass()
        {
            renderPassEvent = clearObjectRenderPassEvent;
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
            GetTempRT(ref tempRTHandle,renderingData);
            ConfigureInput(ScriptableRenderPassInput.Color); //确认传入的参数类型为Color
            ConfigureTarget(tempRTHandle);
        }
        
        //执行传递。这是自定义渲染发生的地方
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (this.renderingData.cameraData.cameraType != CameraType.Game)
            {
                return;
            }
            
            CommandBuffer cmd = CommandBufferPool.Get(ProfilerTag);//获得一个为ProfilerTag的CommandBuffer
            
            //确保执行前清空
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            
            //性能分析器(自带隐式垃圾回收),之后可以在FrameDebugger中查看
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                Blitter.BlitCameraTexture(cmd,cameraColorRTHandle,tempRTHandle);
                cmd.SetGlobalTexture("_GrabTexForClearObject",tempRTHandle);
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
            tempRTHandle?.Release();
        }
    }
    
    //PixelizeObjectCartoonPass
    class PixelizeObjectCartoonPass : ScriptableRenderPass
    {
        private RenderingData renderingData;
        FilteringSettings filtering;
        private List<ShaderTagId> shaderTagsList = new List<ShaderTagId>();
        
        //定义一个 ProfilingSampler 方便设置在FrameDebugger里查看
        private const string ProfilerTag = "PixelizeObjectCartoonPass";
        private ProfilingSampler m_ProfilingSampler = new("PixelizeObjectCartoonPass");
        

        private RTHandle cameraColorRTHandle;
        private RTHandle depthTarget;

        //自定义Pass的构造函数(用于传参)
        public PixelizeObjectCartoonPass(Settings settings)
        {
            filtering = new FilteringSettings(RenderQueueRange.all);//设置过滤器
            shaderTagsList.Add(new ShaderTagId("PixelizeObjectCartoonPass"));
            shaderTagsList.Add(new ShaderTagId("PixelizeObjectOutlinePass"));
            renderPassEvent = pixelizeObjectClearCartoonRenderPassEvent;
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
            
            CommandBuffer cmd = CommandBufferPool.Get(ProfilerTag);//获得一个为ProfilerTag的CommandBuffer
            
            //确保执行前清空
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            
            //性能分析器(自带隐式垃圾回收),之后可以在FrameDebugger中查看
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
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
            
        }
    }
     
     //PixelizeObjectMaskPass
    class PixelizeObjectMaskPass : ScriptableRenderPass
    {
        private RenderingData renderingData;
        FilteringSettings filtering;
        private List<ShaderTagId> shaderTagsList = new List<ShaderTagId>();
        
        //定义一个 ProfilingSampler 方便设置在FrameDebugger里查看
        private const string ProfilerTag = "PixelizeObjectMaskPass";
        private ProfilingSampler m_ProfilingSampler = new("PixelizeObjectMask");
        
        private RTHandle cameraColorRTHandle;//可以理解为GameView_RenderTarget的句柄
        private RTHandle depthTarget;
        private RTHandle maskRTHandle;

        //自定义Pass的构造函数(用于传参)
        public PixelizeObjectMaskPass(Settings settings)
        {
            filtering = new FilteringSettings(RenderQueueRange.all, settings.layerMask);//设置过滤器
            shaderTagsList.Add(new ShaderTagId("PixelizeObjectMaskPass"));
            renderPassEvent = pixelizeObjectClearCartoonRenderPassEvent;
        }

        public void GetTempRT(ref RTHandle temp, in RenderingData data)
        {
            RenderTextureDescriptor desc = data.cameraData.cameraTargetDescriptor;
            desc.colorFormat = RenderTextureFormat.ARGB32;
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
            GetTempRT(ref maskRTHandle,this.renderingData);
            ConfigureTarget(maskRTHandle,depthTarget);
            ConfigureClear(ClearFlag.All, Color.black);
        }
        
        //执行传递。这是自定义渲染发生的地方
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            
            CommandBuffer cmd = CommandBufferPool.Get(ProfilerTag);//获得一个为ProfilerTag的CommandBuffer
            
            //确保执行前清空
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            
            //性能分析器(自带隐式垃圾回收),之后可以在FrameDebugger中查看
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                var depthParams = new RenderStateBlock(RenderStateMask.Depth);
                DepthState depthState = new DepthState(writeEnabled: true, CompareFunction.LessEqual);
                depthParams.depthState = depthState;
            
                SortingCriteria sortingCriteria = SortingCriteria.CommonOpaque;
                var draw = CreateDrawingSettings(shaderTagsList, ref renderingData, sortingCriteria);
                context.DrawRenderers(renderingData.cullResults, ref draw, ref filtering);
                Shader.SetGlobalTexture("_PixelizeObjectMask",maskRTHandle);
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
        }
    }
    
    //PixelizeObjectDepthPass
    class PixelizeObjectDepthPass : ScriptableRenderPass
    {
        private RenderingData renderingData;
        
        //定义一个 ProfilingSampler 方便设置在FrameDebugger里查看
        private const string ProfilerTag = "PixelizeObjectDepthPass";
        private ProfilingSampler m_ProfilingSampler = new("PixelizeObjectDepthPass");
        
        private RTHandle cameraDepth;
        private RTHandle depthTarget;
        
        private RTHandle tempRTHandle;
        
        private Material m_Mat;

        //自定义Pass的构造函数(用于传参)
        public PixelizeObjectDepthPass()
        {
            renderPassEvent = pixelizeObjectClearCartoonRenderPassEvent;
            m_Mat = CoreUtils.CreateEngineMaterial("Hidden/Universal Render Pipeline/CopyDepth");
        }
        
        public void Setup(RTHandle cameraDepth)
        {
            depthTarget = cameraDepth;
        }
        
        //此方法由渲染器在渲染相机之前调用
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;

            //Debug.Log($"当前相机的AAlevel = {desc.msaaSamples}");

            //如果要Blit深度,这些设置很重要
            desc.depthBufferBits = 32;
            desc.colorFormat = RenderTextureFormat.Depth;

            desc.bindMS = false;
            desc.msaaSamples = 1;
        
            RenderingUtils.ReAllocateIfNeeded(ref tempRTHandle, desc);
            cmd.SetGlobalTexture("_DepthTexForPixelizeObject",tempRTHandle);
        }
        
        //执行传递。这是自定义渲染发生的地方
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (renderingData.cameraData.cameraType != CameraType.Game)
            {
                return;
            }

            CommandBuffer cmd = CommandBufferPool.Get(ProfilerTag);
            
            //确保执行前清空
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            
            using (new ProfilingScope(cmd, m_ProfilingSampler)) 
            {
                //可以根据当前相机的AAlevel配置关键字
                m_Mat.EnableKeyword("_DEPTH_MSAA_2");
                m_Mat.DisableKeyword("_DEPTH_MSAA_4");
                m_Mat.DisableKeyword("_DEPTH_MSAA_8");
                m_Mat.EnableKeyword("_OUTPUT_DEPTH");
                Blitter.BlitCameraTexture(cmd,depthTarget,tempRTHandle,m_Mat,0);
            }
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            cmd.Dispose();
        }
        
        //在完成渲染相机时调用
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            
        }
        
        public void OnDispose() 
        {
            if(m_Mat!=null) Object.DestroyImmediate(m_Mat);
        }
    }
    
    //PixelizeObjectGrabPass
    class PixelizeObjectGrabPass : ScriptableRenderPass
    {
        private RenderingData renderingData;
        
        //定义一个 ProfilingSampler 方便设置在FrameDebugger里查看
        private const string ProfilerTag = "PixelizeObjectGrabPass";
        private ProfilingSampler m_ProfilingSampler = new("PixelizeObjectGrabPass");
        
        private RTHandle cameraColorRTHandle;
        private RTHandle depthTarget;
        
        private RTHandle tempRTHandle;

        //自定义Pass的构造函数(用于传参)
        public PixelizeObjectGrabPass()
        {
            renderPassEvent = pixelizeObjectClearCartoonRenderPassEvent;
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
            GetTempRT(ref tempRTHandle,renderingData);
            ConfigureInput(ScriptableRenderPassInput.Color); //确认传入的参数类型为Color
            ConfigureTarget(tempRTHandle);
        }
        
        //执行传递。这是自定义渲染发生的地方
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (this.renderingData.cameraData.cameraType != CameraType.Game)
            {
                return;
            }
            
            CommandBuffer cmd = CommandBufferPool.Get(ProfilerTag);//获得一个为ProfilerTag的CommandBuffer
            
            //确保执行前清空
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            
            //性能分析器(自带隐式垃圾回收),之后可以在FrameDebugger中查看
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                Blitter.BlitCameraTexture(cmd,cameraColorRTHandle,tempRTHandle);
                cmd.SetGlobalTexture("_GrabTexForPixelizeObject",tempRTHandle);
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
            tempRTHandle?.Release();
        }
    }
    
     //PixelizeObjectPass
    class PixelizeObjectPass : ScriptableRenderPass
    {
        private RenderingData renderingData;
        FilteringSettings filtering;
        private List<ShaderTagId> shaderTagsList = new List<ShaderTagId>();
        
        //定义一个 ProfilingSampler 方便设置在FrameDebugger里查看
        private const string ProfilerTag = "PixelizeObjectPass";
        private ProfilingSampler m_ProfilingSampler = new("PixelizeObjectPass");
        

        private RTHandle cameraColorRTHandle;
        private RTHandle depthTarget;

        //自定义Pass的构造函数(用于传参)
        public PixelizeObjectPass(Settings settings)
        {
            filtering = new FilteringSettings(RenderQueueRange.all, settings.layerMask);//设置过滤器
            shaderTagsList.Add(new ShaderTagId("PixelizeObjectPass"));
            renderPassEvent = pixelizeObjectRenderPassEvent;
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
            
            if (Camera.main.orthographic)
            {
                Shader.EnableKeyword("IS_ORTH_CAM");
            }
            else
            {
                Shader.DisableKeyword("IS_ORTH_CAM");
            }
            
            CommandBuffer cmd = CommandBufferPool.Get(ProfilerTag);//获得一个为ProfilerTag的CommandBuffer
            
            //确保执行前清空
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            
            //性能分析器(自带隐式垃圾回收),之后可以在FrameDebugger中查看
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
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
            
        }
    }
    
    //-------------------------------------------------------------------------------------------------------
    private ClearBackGroundObjectGrabPass clearBackGroundObjectGrabPass;
    private PixelizeObjectCartoonPass pixelizeObjectCartoonPass;
    private PixelizeObjectDepthPass pixelizeObjectDepthPass;
    private PixelizeObjectGrabPass pixelizeObjectGrabPass;
    private PixelizeObjectMaskPass pixelizeObjectMaskPass;
    private PixelizeObjectPass pixelizeObjectPass;
    public Settings settings = new Settings();
    
    //初始化时调用
    public override void Create()
    {
        clearBackGroundObjectGrabPass = new ClearBackGroundObjectGrabPass();
        pixelizeObjectCartoonPass = new PixelizeObjectCartoonPass(settings);
        pixelizeObjectDepthPass = new PixelizeObjectDepthPass();
        pixelizeObjectGrabPass = new PixelizeObjectGrabPass();
        pixelizeObjectMaskPass = new PixelizeObjectMaskPass(settings);
        pixelizeObjectPass = new PixelizeObjectPass(settings);
    }
    
    //每帧调用,将pass添加进流程
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(clearBackGroundObjectGrabPass);
        renderer.EnqueuePass(pixelizeObjectCartoonPass);
        renderer.EnqueuePass(pixelizeObjectDepthPass);
        renderer.EnqueuePass(pixelizeObjectGrabPass);
        renderer.EnqueuePass(pixelizeObjectMaskPass);
        renderer.EnqueuePass(pixelizeObjectPass);
    }

    //每帧调用,渲染目标初始化后的回调。这允许在创建并准备好目标后从渲染器访问目标
    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        clearBackGroundObjectGrabPass.Setup(renderer.cameraColorTargetHandle,renderingData);
        pixelizeObjectCartoonPass.Setup(renderer.cameraColorTargetHandle,renderingData);
        pixelizeObjectDepthPass.Setup(renderer.cameraDepthTargetHandle);
        pixelizeObjectGrabPass.Setup(renderer.cameraColorTargetHandle,renderingData);
        pixelizeObjectMaskPass.Setup(renderer.cameraColorTargetHandle,renderingData);//可以理解为传入GameView_RenderTarget的句柄和相机渲染数据（相机渲染数据用于创建TempRT）
        pixelizeObjectPass.Setup(renderer.cameraColorTargetHandle,renderingData);
    }
    
    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        clearBackGroundObjectGrabPass.OnDispose();
        pixelizeObjectCartoonPass.OnDispose();
        pixelizeObjectDepthPass.OnDispose();
        pixelizeObjectGrabPass.OnDispose();
        pixelizeObjectMaskPass.OnDispose();
        pixelizeObjectPass.OnDispose();
    }
}


