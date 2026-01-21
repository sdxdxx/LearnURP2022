using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public sealed class WaterScreenSpaceReflectionRenderFeature : ScriptableRendererFeature
{
    enum ScreenSpaceReflectionType
    {
        Simple_ViewSpace = 1,
        BinarySearch_ViewSpace,
        BinarySearch_Jitter_ViewSpace,
    }

    [System.Serializable]
    public sealed class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        
        [Header("Globals")]
        public string reflectionTexName = "_ScreenSpaceReflectionTexture";
    }

    [SerializeField] public Settings settings = new Settings();

    private WaterSSRPass m_Pass;

    public override void Create()
    {
        m_Pass = new WaterSSRPass(settings)
        {
            renderPassEvent = settings.renderPassEvent
        };
    }

    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
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
    private sealed class WaterSSRPass : ScriptableRenderPass
    {
        private const string k_ProfilerTag = "M_WaterScreenSpaceReflection";
        private readonly ProfilingSampler m_ProfilingSampler = new ProfilingSampler(k_ProfilerTag);

        private static readonly int k_BaseColorId = Shader.PropertyToID("_BaseColor");
        private static readonly int k_StepLengthId = Shader.PropertyToID("_StepLength");
        private static readonly int k_ThicknessId = Shader.PropertyToID("_Thickness");
        private static readonly int k_MaxStepLengthId = Shader.PropertyToID("_MaxStepLength");
        private static readonly int k_MinDistanceId = Shader.PropertyToID("_MinDistance");
        private static readonly int k_MaxReflectLengthId = Shader.PropertyToID("_MaxReflectLength");
        private static readonly int k_DeltaPixelId = Shader.PropertyToID("_DeltaPixel");
        private static readonly int k_DitherIntensityId = Shader.PropertyToID("_DitherIntensity");

        private static readonly string k_KwSimpleVS = "SIMPLE_VS";
        private static readonly string k_KwBinarySearchVS = "BINARY_SEARCH_VS";
        private static readonly string k_KwBinarySearchJitterVS = "BINARY_SEARCH_JITTER_VS";

        private readonly int m_ReflectionTexId;

        private Material m_Material;
        private RTHandle m_CameraColor;
        private RTHandle m_TempRT;

        public WaterSSRPass(Settings settings)
        {
            m_ReflectionTexId = Shader.PropertyToID(settings.reflectionTexName);

            Shader shader = Shader.Find("URP/PostProcessing/WaterScreenSpaceReflection");
            if (shader != null)
                m_Material = CoreUtils.CreateEngineMaterial(shader);

            ConfigureInput(ScriptableRenderPassInput.Color);
        }

        public void Setup(RTHandle cameraColor)
        {
            m_CameraColor = cameraColor;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            ConfigureTarget(m_CameraColor);

            var desc = renderingData.cameraData.cameraTargetDescriptor;
            desc.depthBufferBits = 0;

            RenderingUtils.ReAllocateIfNeeded(
                ref m_TempRT,
                desc,
                FilterMode.Bilinear,
                TextureWrapMode.Clamp,
                name: "_M_WaterSSR_Temp"
            );
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var stack = VolumeManager.instance.stack;
            var volume = stack.GetComponent<ScreenSpaceReflectionVolume>();
            
            var mode = (ScreenSpaceReflectionType)volume.ScreenSpaceReflectionMode.value;

            DisableAllKeywords();

            switch (mode)
            {
                case ScreenSpaceReflectionType.Simple_ViewSpace:
                    m_Material.EnableKeyword(k_KwSimpleVS);
                    break;

                case ScreenSpaceReflectionType.BinarySearch_ViewSpace:
                    m_Material.EnableKeyword(k_KwBinarySearchVS);
                    break;

                case ScreenSpaceReflectionType.BinarySearch_Jitter_ViewSpace:
                    m_Material.EnableKeyword(k_KwBinarySearchJitterVS);
                    break;
            }

            // Params
            m_Material.SetColor(k_BaseColorId, volume.ColorChange.value);

            m_Material.SetFloat(k_StepLengthId, volume.StepLength.value);
            m_Material.SetFloat(k_ThicknessId, volume.Thickness.value);

            m_Material.SetFloat(k_MaxStepLengthId, volume.MaxStepLength.value);
            m_Material.SetFloat(k_MinDistanceId, volume.MinDistance.value);

            m_Material.SetFloat(k_MaxReflectLengthId, volume.MaxReflectLength.value);
            m_Material.SetInt(k_DeltaPixelId, volume.DeltaPixel.value);

            m_Material.SetFloat(k_DitherIntensityId, volume.DitherIntensity.value);

            if (!volume.EnableReflection.value)
                return;

            var cmd = CommandBufferPool.Get(k_ProfilerTag);

            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                // Write SSR into temp RT
                Blitter.BlitCameraTexture(cmd, m_CameraColor, m_TempRT, m_Material, 0);

                if (volume.ShowReflectionTexture.value)
                {
                    // Debug view: display reflection texture
                    Blitter.BlitCameraTexture(cmd, m_TempRT, m_CameraColor);
                }
                else
                {
                    // Provide reflection texture to later shaders
                    cmd.SetGlobalTexture(m_ReflectionTexId, m_TempRT);
                }
            }

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

        private void DisableAllKeywords()
        {
            m_Material.DisableKeyword(k_KwSimpleVS);
            m_Material.DisableKeyword(k_KwBinarySearchVS);
            m_Material.DisableKeyword(k_KwBinarySearchJitterVS);
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
