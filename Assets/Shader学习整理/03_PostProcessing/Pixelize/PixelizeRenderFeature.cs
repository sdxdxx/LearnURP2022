using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class PixelizeFeature : ScriptableRendererFeature
{
    [System.Serializable]
     public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        public LayerMask pixelizeObjectLayer;
    }
     
     //自定义的Pass
    class CustomRenderPass : ScriptableRenderPass
    {
        private RenderingData renderingData;
        FilteringSettings filtering;
        private List<ShaderTagId> shaderTagsList = new List<ShaderTagId>();
        
        //定义一个 ProfilingSampler 方便设置在FrameDebugger里查看
        private const string ProfilerTag = "Pixelize";
        private ProfilingSampler m_ProfilingSampler = new(ProfilerTag);
        
        private Material material;
        private PixelizeVolume pixelizeVolume;

        private RTHandle cameraColorRTHandle;//可以理解为GameView_RenderTarget的句柄
        private RTHandle depthTarget;
        private RTHandle maskRTHandle;
        private RTHandle tempRTHandle;

        //自定义Pass的构造函数(用于传参)
        public CustomRenderPass(Settings settings)
        {
            filtering = new FilteringSettings(RenderQueueRange.all, settings.pixelizeObjectLayer);//设置过滤器
            shaderTagsList.Add(new ShaderTagId("PixelizeMask"));
            
            Shader shader = Shader.Find("URP/PostProcessing/Pixelize");
            renderPassEvent = settings.renderPassEvent; //传入设置的渲染事件顺序(renderPassEvent在基类ScriptableRenderPass中)
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
            depthTarget = renderingData.cameraData.renderer.cameraDepthTargetHandle;
            ConfigureInput(ScriptableRenderPassInput.Color); //确认传入的参数类型为Color
            
            GetTempRT(ref tempRTHandle,this.renderingData);//获取与摄像机大小一致的临时RT
            GetTempRT(ref maskRTHandle,this.renderingData);
            ConfigureTarget(maskRTHandle,depthTarget);
            ConfigureClear(ClearFlag.All, Color.black);
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
            
            var stack = VolumeManager.instance.stack;//获取Volume的栈
            pixelizeVolume = stack.GetComponent<PixelizeVolume>();//从栈中获取到Volume
            material.SetColor("_BaseColor", pixelizeVolume.ColorChange.value);//将材质颜色设置为volume中的值
            material.SetInt("_DownSampleValue", pixelizeVolume.DownSampleValue.value);
            
            
            if (pixelizeVolume.EnablePixelizer.value)
            {
                
                //性能分析器(自带隐式垃圾回收),之后可以在FrameDebugger中查看
                using (new ProfilingScope(cmd, m_ProfilingSampler))
                {
                    // Ensure we flush our command-buffer before we render...
                    context.ExecuteCommandBuffer(cmd);
                    cmd.Clear();
                
                    /* // 强制深度写入
                    var depthParams = new RenderStateBlock(RenderStateMask.Depth);
                    DepthState depthState = new DepthState(writeEnabled: true, CompareFunction.LessEqual);
                    depthParams.depthState = depthState;
                    */
                
                    SortingCriteria sortingCriteria = SortingCriteria.CommonOpaque;
                    var draw = CreateDrawingSettings(shaderTagsList, ref renderingData, sortingCriteria);
                    context.DrawRenderers(renderingData.cullResults, ref draw, ref filtering);
                
                    Shader.SetGlobalTexture("_PixelizeMask",maskRTHandle);
                    
                    Blitter.BlitCameraTexture(cmd,cameraColorRTHandle,tempRTHandle);
                    Blitter.BlitCameraTexture(cmd,tempRTHandle,cameraColorRTHandle,material,0);//写入渲染命令进CommandBuffer
                }
                
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
            maskRTHandle?.Release();
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


