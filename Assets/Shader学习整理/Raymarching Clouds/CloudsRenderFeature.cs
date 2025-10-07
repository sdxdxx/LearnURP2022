using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class CloudsRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]
     public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        public Shader shader;
    }
     
     //自定义的Pass
    class CustomRenderPass : ScriptableRenderPass
    {
        private RenderingData renderingData;
        
        //定义一个 ProfilingSampler 方便设置在FrameDebugger里查看
        private const string ProfilerTag = "CloudsRenderFeature";
        private ProfilingSampler m_ProfilingSampler = new(ProfilerTag);
        
        private Material material;
        private CloudsVolume cloudsVolume;

        private RTHandle cameraColorRTHandle;//可以理解为GameView_RenderTarget的句柄
        private RTHandle tempRTHandle;
        private RTHandle downSampleTexRTHandle;

        //自定义Pass的构造函数(用于传参)
        public CustomRenderPass(RenderPassEvent evt, Shader shader)
        {
            renderPassEvent = evt; //传入设置的渲染事件顺序(renderPassEvent在基类ScriptableRenderPass中)

            if (shader)
            {
                material = CoreUtils.CreateEngineMaterial(shader);//根据传入的Shader创建material;
            }
        }

        public void GetTempRT(ref RTHandle temp, in RenderingData data, int downSample, bool enableAlpha)
        {
            RenderTextureDescriptor desc = data.cameraData.cameraTargetDescriptor;
            desc.depthBufferBits = 0; //这步很重要！！！
            desc.height = desc.height / downSample;
            desc.width = desc.width / downSample;
            if (enableAlpha)
            {
                desc.colorFormat = RenderTextureFormat.ARGB32;
            }
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
        }
        
        //执行传递。这是自定义渲染发生的地方
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {

            if (!material)
            {
                return;
            }
            
            //Only Game Camera can Render
            if (renderingData.cameraData.cameraType != CameraType.Game)
            {
                return;
            }

            var stack = VolumeManager.instance.stack;//获取Volume的栈
            cloudsVolume = stack.GetComponent<CloudsVolume>();//从栈中获取到CloudsVolume
            
            bool enableEffect = cloudsVolume.EnableEffect.value;
            if (enableEffect)
            {
                CommandBuffer cmd = CommandBufferPool.Get(ProfilerTag);//获得一个为ProfilerTag的CommandBuffer
                
                GetTempRT(ref downSampleTexRTHandle,this.renderingData,cloudsVolume.DownSampleValue.value,true);
                GetTempRT(ref tempRTHandle,this.renderingData,cloudsVolume.DownSampleValue.value,true);

                if (cloudsVolume.EnableSkyMask.value)
                {
                    material.SetFloat("_SkyMaskValue",cloudsVolume.SkyMaskValue.value);
                }
                else
                {
                    material.SetFloat("_SkyMaskValue",0f);
                }
                
            
                material.SetColor("_BaseColor", cloudsVolume.CloudColor.value);//将材质颜色设置为volume中的值
                
                material.SetFloat("_StepTime",cloudsVolume.StepTime.value);
                
                material.SetFloat("_BlurRange",cloudsVolume.BlurRange.value);
                
                //Noise
                material.SetTexture("_NoiseTex",cloudsVolume.NoiseTex.value);
                material.SetTexture("_DetailNoiseTex",cloudsVolume.DetailNoiseTex.value);
                material.SetTexture("_MaskNoise",cloudsVolume.MaskNoise.value);
                material.SetTexture("_BlueNoise",cloudsVolume.BlueNoise.value);
                material.SetFloat("_NosieTexScale",cloudsVolume.NoiseTexScale.value);
                material.SetFloat("_DetailNosieTexScale",cloudsVolume.DetailNoiseTexScale.value);
                material.SetVector("_NoiseTexOffset",cloudsVolume.NoiseTexOffset.value);
                material.SetVector("_BlueNoiseTillingOffset",cloudsVolume.BlueNoiseTillingOffset.value);
                material.SetVector("_shapeNoiseWeights",cloudsVolume.shapeNoiseWeights.value);
                material.SetFloat("_detailWeights",cloudsVolume.detailWeights.value);
                material.SetFloat("_detailNoiseWeight",cloudsVolume.detailNoiseWeight.value);
                material.SetFloat("_rayOffsetStrength",cloudsVolume.rayOffsetStrength.value);
                
                //Density
                material.SetTexture("_WeatherMap",cloudsVolume.WeatherMap.value);
                material.SetFloat("_densityOffset",cloudsVolume.densityOffset.value);
                material.SetFloat("_densityMultiplier",cloudsVolume.densityMultiplier.value);
                material.SetFloat("_heightWeights",cloudsVolume.heightWeights.value);
                
                //Light
                material.SetColor("_colA",cloudsVolume.colA.value);
                material.SetColor("_colB",cloudsVolume.colB.value);
                material.SetFloat("_colorOffset1",cloudsVolume.colorOffset1.value);
                material.SetFloat("_colorOffset2",cloudsVolume.colorOffset2.value);
                material.SetFloat("_lightAbsorptionTowardSun",cloudsVolume.lightAbsorptionTowardSun.value);
                
                //散射
                material.SetVector("_phaseParams", cloudsVolume.phaseParams.value);
                
                //移动速度
                material.SetFloat("_WeatherMapScale",cloudsVolume.WeatherMapScale.value);
                material.SetVector("_xy_Speed_zw_Warp",cloudsVolume.xy_Speed_zw_Warp.value);
                material.SetVector("_xy_WeatherSpeed",cloudsVolume.xy_WeatherSpeed.value);


                //性能分析器(自带隐式垃圾回收),之后可以在FrameDebugger中查看
                using (new ProfilingScope(cmd, m_ProfilingSampler))
                {
                    Blitter.BlitCameraTexture(cmd,downSampleTexRTHandle,downSampleTexRTHandle,material,0);//降采样
                    Blitter.BlitCameraTexture(cmd,downSampleTexRTHandle,tempRTHandle,material,1);//Blur
                    material.SetTexture("_CloudMap",tempRTHandle);
                    Blitter.BlitCameraTexture(cmd,cameraColorRTHandle,cameraColorRTHandle,material,2);//写入渲染命令进CommandBuffer
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
            downSampleTexRTHandle?.Release();
            tempRTHandle?.Release();
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


