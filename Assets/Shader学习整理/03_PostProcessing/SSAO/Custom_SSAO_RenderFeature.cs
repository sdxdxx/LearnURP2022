using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class Custom_SSAO_RenderFeature : ScriptableRendererFeature
{
    [System.Serializable]
     public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        public Shader shader;
    }
     
     //自定义的Pass
     //-------------------------------------------------------------------------------------------------------
    class CustomRenderPass : ScriptableRenderPass
    {
        private RenderingData renderingData;
        
        //定义一个 ProfilingSampler 方便设置在FrameDebugger里查看
        private const string ProfilerTag = "Custom_SSAO";
        private ProfilingSampler m_ProfilingSampler = new(ProfilerTag);

        private Material material;
        private Custom_SSAO_Volume volume;

        private float intensity = 0.727f; 
        private float cullValue = 0.2f;
        private float depthBias = 0.00012f;
        
        private int sampleCount = 16;
        private List<Vector4> sampleList = new List<Vector4>();
        private float sampleRadius = 0.32f;
        private float insideRadius = 0.08f;

        private bool blur;
        private float blurRadius = 3f;
        private float bilaterFilterStrength = 0.003f;
        
        private bool ssao_Only = false;

        private RTHandle cameraColorRTHandle;//可以理解为GameView_RenderTarget的句柄
        private RTHandle tempRTHandle01;
        private RTHandle tempRTHandle02;

        //自定义Pass的构造函数(用于传参)
        public CustomRenderPass(RenderPassEvent evt, Shader shader)
        {
            renderPassEvent = evt; //传入设置的渲染事件顺序(renderPassEvent在基类ScriptableRenderPass中)
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
            
            if (renderingData.cameraData.cameraType != CameraType.Game)
            {
                return;
            }
            
            GetTempRT(ref tempRTHandle01,this.renderingData);
            GetTempRT(ref tempRTHandle02,this.renderingData);
            
            var stack = VolumeManager.instance.stack;//获取Volume的栈
            volume = stack.GetComponent<Custom_SSAO_Volume>();
            
            if (volume)
            {
                intensity = volume.Intensity.value;
                cullValue = volume.CullValue.value;
                depthBias = volume.DepthBias.value;
                sampleCount = volume.SampleCount.value;
                sampleRadius = volume.SampleRadius.value;
                insideRadius = volume.InsideRadius.value;
                bilaterFilterStrength = volume.BilaterFilterStrength.value;
                blurRadius = volume.BlurRadius.value;
                blur = volume.Blur.value;
                ssao_Only = volume.SSAO_Only.value;
            }
            
            insideRadius = Mathf.Min(insideRadius, sampleRadius);
            material.SetFloat("_Intensity",intensity);
            material.SetFloat("_CullValue",cullValue);
            material.SetFloat("_DepthBias",depthBias);
            material.SetInt("_SampleCount",sampleCount);
            material.SetFloat("_SampleRadius",sampleRadius);
            material.SetFloat("_InsideRadius",insideRadius);
            material.SetFloat("_BilaterFilterFactor",1.0f-bilaterFilterStrength);
        }
        
        //执行传递。这是自定义渲染发生的地方
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            //已通过修改源码解决
            //仅在游戏模式下运行
            
            if (renderingData.cameraData.cameraType != CameraType.Game)
            {
                return;
            }
            
            
            //没有volume或者没有开启Effect则不开启SSAO
            if (!volume||!volume.EnableEffect.value)
            {
                return;
            }
            
            CommandBuffer cmd = CommandBufferPool.Get(ProfilerTag);//获得一个为ProfilerTag的CommandBuffer
            
            //性能分析器(自带隐式垃圾回收),之后可以在FrameDebugger中查看
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                Blitter.BlitCameraTexture(cmd,cameraColorRTHandle,tempRTHandle01,material,0);
                
                if (blur)
                {
                    material.SetVector("_BlurRadius",new Vector4(blurRadius,0,0,0));
                    Blitter.BlitCameraTexture(cmd,tempRTHandle01,tempRTHandle02,material,1);
                    material.SetVector("_BlurRadius",new Vector4(0,blurRadius,0,0));
                    Blitter.BlitCameraTexture(cmd,tempRTHandle02,tempRTHandle01,material,1);
                }
                
                material.SetTexture("_AOTex",tempRTHandle01);

                if (ssao_Only)
                {
                    Blitter.BlitCameraTexture(cmd,tempRTHandle01,cameraColorRTHandle);
                }
                else
                {
                    Blitter.BlitCameraTexture(cmd,cameraColorRTHandle,tempRTHandle02,material,2);
                    Blitter.BlitCameraTexture(cmd,tempRTHandle02,cameraColorRTHandle);
                }


            }
            
            context.ExecuteCommandBuffer(cmd);//执行CommandBuffer
            cmd.Clear();
            cmd.Dispose();
        }
        
        //在完成渲染相机时调用
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            
        }
        
        public void OnDispose() 
        {
            CoreUtils.Destroy(material);
            tempRTHandle01?.Release();
            tempRTHandle02?.Release();
        }
    }
    //-------------------------------------------------------------------------------------------------------
    private CustomRenderPass m_ScriptablePass;
    public Settings settings = new Settings();
    
    //初始化时调用
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass(settings.renderPassEvent,settings.shader);
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