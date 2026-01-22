using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public sealed class UnderWaterRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public sealed class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    }

    [SerializeField] public Settings settings = new Settings();

    private UnderWaterPass m_Pass;

    public override void Create()
    {
        m_Pass = new UnderWaterPass()
        {
            renderPassEvent = settings.renderPassEvent
        };
    }

    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        if (ShouldSkip(in renderingData))
            return;

        m_Pass.Setup(renderer.cameraColorTargetHandle);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (ShouldSkip(in renderingData))
            return;

        renderer.EnqueuePass(m_Pass);
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        m_Pass?.Dispose();
        m_Pass = null;
    }

    private static bool ShouldSkip(in RenderingData renderingData)
    {
        var cameraData = renderingData.cameraData;

        if (cameraData.cameraType == CameraType.Preview)
            return true;

        if (cameraData.renderType == CameraRenderType.Overlay)
            return true;

        // 只支持 Game / SceneView（你的原逻辑就是主要用这两个）
        if (cameraData.cameraType != CameraType.Game && cameraData.cameraType != CameraType.SceneView)
            return true;

        return false;
    }

    // ============================================================================================
    // Pass
    // ============================================================================================
    private sealed class UnderWaterPass : ScriptableRenderPass
    {
        private const string k_ProfilerTag = "M_UnderWaterMask";
        private readonly ProfilingSampler m_ProfilingSampler = new ProfilingSampler(k_ProfilerTag);

        private static readonly int k_WaveAId = Shader.PropertyToID("_WaveA");
        private static readonly int k_WaveBId = Shader.PropertyToID("_WaveB");
        private static readonly int k_WaveCId = Shader.PropertyToID("_WaveC");
        private static readonly int k_WaveIntensityId = Shader.PropertyToID("_WaveInt");

        private static readonly int k_UnderWaterDeepColorId = Shader.PropertyToID("_UnderWaterDeepColor");
        private static readonly int k_UnderWaterShallowColorId = Shader.PropertyToID("_UnderWaterShallowColor");
        private static readonly int k_UnderWaterFogColorId = Shader.PropertyToID("_UnderWaterFogColor");
        private static readonly int k_UnderWaterFogDensityMinId = Shader.PropertyToID("_UnderWaterFogDensityMin");
        private static readonly int k_UnderWaterFogDensityMaxId = Shader.PropertyToID("_UnderWaterFogDensityMax");

        private static readonly int k_DistorationNoiseId = Shader.PropertyToID("_DistorationNoise");
        private static readonly int k_DistorationNoiseTillingId = Shader.PropertyToID("_DistorationNoise_Tilling");
        private static readonly int k_DistorationIntensityId = Shader.PropertyToID("_DistorationIntensity");
        private static readonly int k_DistorationSpeedId = Shader.PropertyToID("_DistorationSpeed");

        private static readonly int k_CausticsTextureId = Shader.PropertyToID("_CausticsTexture");
        private static readonly int k_CausticsTextureScaleId = Shader.PropertyToID("_CausticsTextureScale");
        private static readonly int k_CausticsSpeedId = Shader.PropertyToID("_CausticsSpeed");
        private static readonly int k_CausticsIntensityId = Shader.PropertyToID("_CausticsIntensity");

        private static readonly int k_UnderWaterLineWidthId = Shader.PropertyToID("_UnderWaterLineWidth");
        private static readonly int k_WaterLineSmoothId = Shader.PropertyToID("_WaterLineSmooth");
        private static readonly int k_WaterLineOffsetId = Shader.PropertyToID("_WaterLineOffset");
        private static readonly int k_WaterLineColorId = Shader.PropertyToID("_WaterLineColor");

        private static readonly int k_IsEditorGlobalModeId = Shader.PropertyToID("_isEditorGlobalMode");

        private RTHandle m_CameraColorRenderTargetHandle;
        private RTHandle m_TempColorRenderTargetHandle;

        private Material m_Material;

        public UnderWaterPass()
        {
            Shader shader = Shader.Find("URP/PostProcessing/UnderWater");
            if (shader != null)
                m_Material = CoreUtils.CreateEngineMaterial(shader);

            ConfigureInput(ScriptableRenderPassInput.Color);
        }

        public void Setup(RTHandle cameraColorRenderTargetHandle)
        {
            m_CameraColorRenderTargetHandle = cameraColorRenderTargetHandle;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            var desc = renderingData.cameraData.cameraTargetDescriptor;
            desc.depthBufferBits = 0;

            RenderingUtils.ReAllocateIfNeeded(
                ref m_TempColorRenderTargetHandle,
                desc,
                FilterMode.Bilinear,
                TextureWrapMode.Clamp,
                name: "_M_UnderWater_Temp"
            );

            ConfigureTarget(m_CameraColorRenderTargetHandle);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (m_Material == null)
                return;

            var stack = VolumeManager.instance.stack;
            var waterVolume = stack.GetComponent<WaterVolume>();

            // 原代码就是全局写入（即使效果关闭也更新波浪参数）
            Shader.SetGlobalVector(k_WaveAId, waterVolume.WaveA.value);
            Shader.SetGlobalVector(k_WaveBId, waterVolume.WaveB.value);
            Shader.SetGlobalVector(k_WaveCId, waterVolume.WaveC.value);
            Shader.SetGlobalFloat(k_WaveIntensityId, waterVolume.WaveInt.value);

            if (!waterVolume.EnableEffect.value)
                return;

            // SceneView：只有 EnableGlobalEffect_Editor 开启才渲染
            bool isGameCamera = renderingData.cameraData.cameraType == CameraType.Game;
            bool allowSceneViewGlobal = !isGameCamera && waterVolume.EnableGlobalEffect_Editor.value;

            if (isGameCamera)
            {
                if (renderingData.cameraData.camera != Camera.main)
                    return;

                m_Material.SetInteger(k_IsEditorGlobalModeId, 0);
            }
            else
            {
                if (!allowSceneViewGlobal)
                    return;

                m_Material.SetInteger(k_IsEditorGlobalModeId, 1);
            }

            // Params
            m_Material.SetColor(k_UnderWaterDeepColorId, waterVolume.UnderWaterDeepColor.value);
            m_Material.SetColor(k_UnderWaterShallowColorId, waterVolume.UnderWaterShallowColor.value);
            m_Material.SetColor(k_UnderWaterFogColorId, waterVolume.UnderWaterFogColor.value);
            m_Material.SetFloat(k_UnderWaterFogDensityMinId, waterVolume.UnderWaterFogDensityMin.value);
            m_Material.SetFloat(k_UnderWaterFogDensityMaxId, waterVolume.UnderWaterFogDensityMax.value);

            m_Material.SetTexture(k_DistorationNoiseId, waterVolume.DistorationNoise.value);
            m_Material.SetVector(k_DistorationNoiseTillingId, waterVolume.DistorationNoise_Tilling.value);
            m_Material.SetFloat(k_DistorationIntensityId, waterVolume.DistorationIntensity.value);
            m_Material.SetFloat(k_DistorationSpeedId, waterVolume.DistorationSpeed.value);

            m_Material.SetTexture(k_CausticsTextureId, waterVolume.CausticsTexture.value);
            m_Material.SetFloat(k_CausticsTextureScaleId, waterVolume.CausticsTextureScale.value);
            m_Material.SetFloat(k_CausticsSpeedId, waterVolume.CausiticsSpeed.value);
            m_Material.SetFloat(k_CausticsIntensityId, waterVolume.CausiticsIntensity.value);

            m_Material.SetFloat(k_UnderWaterLineWidthId, waterVolume.WaterLineWidth.value);
            m_Material.SetFloat(k_WaterLineSmoothId, waterVolume.WaterLineSmooth.value);
            m_Material.SetFloat(k_WaterLineOffsetId, waterVolume.WaterLineOffset.value);
            m_Material.SetColor(k_WaterLineColorId, waterVolume.WaterLineColor.value);

            CommandBuffer cmd = CommandBufferPool.Get(k_ProfilerTag);

            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                Blitter.BlitCameraTexture(cmd, m_CameraColorRenderTargetHandle, m_TempColorRenderTargetHandle);
                Blitter.BlitCameraTexture(cmd, m_TempColorRenderTargetHandle, m_CameraColorRenderTargetHandle, m_Material, 1);
            }

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

        public void Dispose()
        {
            m_TempColorRenderTargetHandle?.Release();
            m_TempColorRenderTargetHandle = null;

            CoreUtils.Destroy(m_Material);
            m_Material = null;
        }
    }
}
