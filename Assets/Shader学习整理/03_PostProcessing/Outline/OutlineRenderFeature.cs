using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class OutlineRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]
     public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        public LayerMask outlineLayer;
        public Shader shader;
    }
     
     //自定义的Pass
    class CustomRenderPass : ScriptableRenderPass
    {
        FilteringSettings filtering;
        private List<ShaderTagId> shaderTagsList = new List<ShaderTagId>();
        
        //定义一个 ProfilingSampler 方便设置在FrameDebugger里查看
        private const string ProfilerTag = "Outline";
        private ProfilingSampler m_ProfilingSampler = new(ProfilerTag);
        
        private Material material;

        private OutlineVolume outlineVolume;

        private RTHandle cameraColorRTHandle;//可以理解为GameView_RenderTarget的句柄
        private RTHandle tempRTHandle;
        private RTHandle tempRTHandle2;
        private RTHandle tempRTHandle3;

        //自定义Pass的构造函数(用于传参)
        public CustomRenderPass(Settings settings)
        {
            renderPassEvent = settings.renderPassEvent; //传入设置的渲染事件顺序(renderPassEvent在基类ScriptableRenderPass中)
            material = CoreUtils.CreateEngineMaterial(settings.shader);//根据传入的Shader创建material;
            
            filtering = new FilteringSettings(RenderQueueRange.all, settings.outlineLayer);//设置过滤器
            //shaderTagsList.Add(new ShaderTagId("SRPDefaultUnlit"));
            //shaderTagsList.Add(new ShaderTagId("UniversalForward"));
            //shaderTagsList.Add(new ShaderTagId("UniversalForwardOnly"));
            shaderTagsList.Add(new ShaderTagId("OutlineMask"));
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
            
            GetTempRT(ref tempRTHandle,renderingData);//获取与摄像机大小一致的临时RT
            GetTempRT(ref tempRTHandle2,renderingData);//获取与摄像机大小一致的临时RT
            GetTempRT(ref tempRTHandle3,renderingData);//获取与摄像机大小一致的临时RT
            
            ConfigureTarget(tempRTHandle3);
            //将RT清空为黑
            ConfigureClear(ClearFlag.All, Color.black);
        }
        
        
        //执行传递。这是自定义渲染发生的地方
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (material==null)
            {
                return;
            }
            
            if (renderingData.cameraData.cameraType != CameraType.Game)
            {
                return;
            }
            
            
            //Only main Camera can Render
            if (renderingData.cameraData.camera != Camera.main)
            {
                return;
            }
            
            var stack = VolumeManager.instance.stack;//获取Volume的栈
            outlineVolume = stack.GetComponent<OutlineVolume>();//从栈中获取到ColorTintVolume
            material.SetColor("_OutlineColor", outlineVolume.OutlineColor.value);//将材质颜色设置为volume中的值
            material.SetFloat("_Rate",outlineVolume.Rate.value);
            CommandBuffer cmd = CommandBufferPool.Get(m_ProfilingSampler.name);//获得一个为ProfilerTag的CommandBuffer
            
            //性能分析器(自带隐式垃圾回收),之后可以在FrameDebugger中查看
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
            
                SortingCriteria sortingCriteria = SortingCriteria.CommonOpaque;
                var draw = CreateDrawingSettings(shaderTagsList, ref renderingData, sortingCriteria);
                draw.overrideMaterial = material;
                draw.overrideMaterialPassIndex = 0;
                context.DrawRenderers(renderingData.cullResults, ref draw, ref filtering);
                
                
                material.SetTexture("_OutlineMask",tempRTHandle3);

                ConfigureTarget(cameraColorRTHandle);//确认传入的目标为cameraColorRT

                
                Blitter.BlitCameraTexture(cmd,cameraColorRTHandle,tempRTHandle);
                Blitter.BlitCameraTexture(cmd,tempRTHandle,cameraColorRTHandle,material,1);
                
                
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
            tempRTHandle2?.Release();//如果tempRTHandle2没被释放的话，会被释放
            tempRTHandle3?.Release();//如果tempRTHandle2没被释放的话，会被释放
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
        m_ScriptablePass.Setup(renderer.cameraColorTargetHandle);//可以理解为传入GameView_RenderTarget的句柄和相机渲染数据（相机渲染数据用于创建TempRT）
    }
    
    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        m_ScriptablePass.OnDispose();
    }
}


