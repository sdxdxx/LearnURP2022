using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public sealed class ColorTintRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public sealed class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        public Shader shader;
    }

    [SerializeField] public Settings settings = new Settings();

    private ColorTintPass m_Pass;

    public override void Create()
    {
        // 如果 shader 没配，pass 仍然创建，但会在执行时跳过
        m_Pass = new ColorTintPass(settings.renderPassEvent, settings.shader);
    }

    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        // 直接把 cameraColor 传进去即可；
        m_Pass.Setup(renderer.cameraColorTargetHandle);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_Pass);
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        m_Pass?.Dispose();
        m_Pass = null;
    }

    // ============================================================================================
    // Pass
    // ============================================================================================
    private sealed class ColorTintPass : ScriptableRenderPass
    {
        private const string k_ProfilerTag = "M_ColorTint";
        private static readonly int k_BaseColorId = Shader.PropertyToID("_BaseColor");

        private readonly ProfilingSampler m_ProfilingSampler = new ProfilingSampler(k_ProfilerTag);

        private Material m_Material;
        private RTHandle m_CameraColor;
        private RTHandle m_TempRT;

        public ColorTintPass(RenderPassEvent evt, Shader shader)
        {
            renderPassEvent = evt;

            // 这个 pass 需要读取 camera color
            ConfigureInput(ScriptableRenderPassInput.Color);

            if (shader != null)
                m_Material = CoreUtils.CreateEngineMaterial(shader);
        }

        public void Setup(RTHandle cameraColor)
        {
            m_CameraColor = cameraColor;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            // 如果没有材质（shader 没配或创建失败），不分配 RT，直接在 Execute 里跳过
            if (m_Material == null)
                return;
            
            ConfigureTarget(m_CameraColor);

            // 临时 RT：与相机一致，且不需要 depth
            var desc = renderingData.cameraData.cameraTargetDescriptor;
            desc.depthBufferBits = 0;

            RenderingUtils.ReAllocateIfNeeded(
                ref m_TempRT,
                desc,
                FilterMode.Bilinear,
                TextureWrapMode.Clamp,
                name: "_M_ColorTint_Temp"
            );
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            // 取 Volume 参数
            var stack = VolumeManager.instance.stack;
            var volume = stack.GetComponent<ColorTintVolume>();

            // 没有组件或未启用时，跳过（避免每帧无意义 blit）
            // if (volume == null || !volume.active)
            //     return;

            m_Material.SetColor(k_BaseColorId, volume.ColorChange.value);

            var cmd = CommandBufferPool.Get(k_ProfilerTag);

            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                
                Blitter.BlitCameraTexture(cmd, m_CameraColor, m_TempRT);

                
                Blitter.BlitCameraTexture(cmd, m_TempRT, m_CameraColor, m_Material, 0);
            }

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

        public void Dispose()
        {
            m_TempRT?.Release();
            m_TempRT = null;

            CoreUtils.Destroy(m_Material);
            m_Material = null;
        }
    }
}
