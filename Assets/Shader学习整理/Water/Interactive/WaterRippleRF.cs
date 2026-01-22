using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public sealed class WaterRippleRF : ScriptableRendererFeature
{
    [System.Serializable]
    public sealed class Settings
    {
        public LayerMask layerMask = ~0;
    }

    [SerializeField] public Settings settings = new Settings();

    private const RenderPassEvent k_WaterRipplePassEvent = RenderPassEvent.AfterRenderingPrePasses;
    private static readonly int k_WaterRippleTextureId = Shader.PropertyToID("_WaterRipple");

    private RTHandle m_MaskTextureHandle;
    private RTHandle m_DepthTextureHandle;

    private WaterRipplePass m_Pass;

    public override void Create()
    {
        m_Pass = new WaterRipplePass(settings)
        {
            renderPassEvent = k_WaterRipplePassEvent
        };
    }

    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        if (ShouldSkip(in renderingData))
            return;

        AllocateTargets(in renderingData);
        m_Pass.Setup(m_MaskTextureHandle, m_DepthTextureHandle);
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

        m_MaskTextureHandle?.Release();
        m_MaskTextureHandle = null;

        m_DepthTextureHandle?.Release();
        m_DepthTextureHandle = null;

        m_Pass = null;
    }

    private static bool ShouldSkip(in RenderingData renderingData)
    {
        var cameraData = renderingData.cameraData;

        if (cameraData.cameraType == CameraType.Preview)
            return true;

        if (cameraData.renderType == CameraRenderType.Overlay)
            return true;

        if (cameraData.cameraType != CameraType.Game && cameraData.cameraType != CameraType.SceneView)
            return true;

        return false;
    }

    private void AllocateTargets(in RenderingData renderingData)
    {
        RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;

        RenderTextureDescriptor maskDescriptor = desc;
        maskDescriptor.depthBufferBits = 0;
        maskDescriptor.colorFormat = RenderTextureFormat.ARGB32;

        RenderingUtils.ReAllocateIfNeeded(ref m_MaskTextureHandle, maskDescriptor, name: "_M_WaterRippleMask");

        RenderTextureDescriptor depthDescriptor = desc;
        depthDescriptor.depthBufferBits = 32;
        depthDescriptor.colorFormat = RenderTextureFormat.Depth;

        RenderingUtils.ReAllocateIfNeeded(ref m_DepthTextureHandle, depthDescriptor, name: "_M_WaterRippleDepth");
    }

    // ============================================================================================
    // Pass
    // ============================================================================================
    private sealed class WaterRipplePass : ScriptableRenderPass
    {
        private const string k_ProfilerTag = "M_WaterRipplePass";
        private readonly ProfilingSampler m_ProfilingSampler = new ProfilingSampler(k_ProfilerTag);

        private static readonly ShaderTagId k_ShaderTagId = new ShaderTagId("WaterRipple");

        private FilteringSettings m_FilteringSettings;

        private RTHandle m_MaskTextureHandle;
        private RTHandle m_DepthTextureHandle;

        public WaterRipplePass(Settings settings)
        {
            m_FilteringSettings = new FilteringSettings(RenderQueueRange.all, settings.layerMask);
            ConfigureInput(ScriptableRenderPassInput.None);
        }

        public void Setup(RTHandle maskTextureHandle, RTHandle depthTextureHandle)
        {
            m_MaskTextureHandle = maskTextureHandle;
            m_DepthTextureHandle = depthTextureHandle;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            ConfigureTarget(m_MaskTextureHandle, m_DepthTextureHandle);
            ConfigureClear(ClearFlag.All, Color.black);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(k_ProfilerTag);

            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                SortingCriteria sortingCriteria = SortingCriteria.CommonTransparent;
                DrawingSettings drawingSettings = CreateDrawingSettings(k_ShaderTagId, ref renderingData, sortingCriteria);

                context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref m_FilteringSettings);

                cmd.SetGlobalTexture(k_WaterRippleTextureId, m_MaskTextureHandle);
            }

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }
    }
}
