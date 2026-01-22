using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public sealed class GasussianBlurRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public sealed class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    }

    [SerializeField] 
    public Settings settings = new Settings();

    private GaussianBlurPass m_Pass;

    public override void Create()
    {
        m_Pass = new GaussianBlurPass(settings)
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

        return false;
    }

    // ============================================================================================
    // Pass
    // ============================================================================================
    private sealed class GaussianBlurPass : ScriptableRenderPass
    {
        private const string k_ProfilerTag = "M_GaussianBlur";
        private readonly ProfilingSampler m_ProfilingSampler = new ProfilingSampler(k_ProfilerTag);

        private static readonly int k_BaseColorId = Shader.PropertyToID("_BaseColor");
        private static readonly int k_BlurSizeId = Shader.PropertyToID("_BlurSize");

        private RTHandle m_CameraColorRenderTargetHandle;
        private RTHandle m_TempColorRenderTargetAHandle;
        private RTHandle m_TempColorRenderTargetBHandle;

        private Material m_Material;

        public GaussianBlurPass(Settings settings)
        {
            Shader shader = Shader.Find("URP/PostProcessing/GaussianBlur");
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
            if (m_Material == null)
                return;

            ConfigureTarget(m_CameraColorRenderTargetHandle);

            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
            desc.depthBufferBits = 0;
            desc.msaaSamples = 1;
            desc.bindMS = false;

            RenderingUtils.ReAllocateIfNeeded(
                ref m_TempColorRenderTargetAHandle,
                desc,
                FilterMode.Bilinear,
                TextureWrapMode.Clamp,
                name: "_M_GaussianBlur_TempA"
            );

            RenderingUtils.ReAllocateIfNeeded(
                ref m_TempColorRenderTargetBHandle,
                desc,
                FilterMode.Bilinear,
                TextureWrapMode.Clamp,
                name: "_M_GaussianBlur_TempB"
            );
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (m_Material == null)
                return;

            var stack = VolumeManager.instance.stack;
            var gaussianBlurVolume = stack.GetComponent<GaussianBlurVolume>();

            m_Material.SetColor(k_BaseColorId, gaussianBlurVolume.ColorChange.value);
            m_Material.SetFloat(k_BlurSizeId, gaussianBlurVolume.BlurSize.value);

            CommandBuffer cmd = CommandBufferPool.Get(k_ProfilerTag);

            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                // Copy camera color -> TempA
                Blitter.BlitCameraTexture(cmd, m_CameraColorRenderTargetHandle, m_TempColorRenderTargetAHandle);

                // Blur pass 0: TempA -> TempB
                Blitter.BlitCameraTexture(cmd, m_TempColorRenderTargetAHandle, m_TempColorRenderTargetBHandle, m_Material, 0);

                // Blur pass 1: TempB -> Camera color
                Blitter.BlitCameraTexture(cmd, m_TempColorRenderTargetBHandle, m_CameraColorRenderTargetHandle, m_Material, 1);
            }

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

        public void Dispose()
        {
            m_TempColorRenderTargetAHandle?.Release();
            m_TempColorRenderTargetAHandle = null;

            m_TempColorRenderTargetBHandle?.Release();
            m_TempColorRenderTargetBHandle = null;

            CoreUtils.Destroy(m_Material);
            m_Material = null;
        }
    }
}
