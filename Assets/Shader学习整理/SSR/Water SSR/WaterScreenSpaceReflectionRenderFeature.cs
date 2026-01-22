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
    private WaterColorWithoutReflectionPass m_WaterColorWithoutReflectionPass;

    public override void Create()
    {
        m_Pass = new WaterSSRPass(settings)
        {
            renderPassEvent = settings.renderPassEvent
        };

        m_WaterColorWithoutReflectionPass = new WaterColorWithoutReflectionPass();
    }

    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        if (!ShouldSkip(in renderingData))
        {
            m_Pass.Setup(renderer.cameraColorTargetHandle);
            m_WaterColorWithoutReflectionPass.Setup(renderer.cameraDepthTargetHandle);
        }
        
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (!ShouldSkip(in renderingData))
        {
            renderer.EnqueuePass(m_WaterColorWithoutReflectionPass);
            renderer.EnqueuePass(m_Pass);
        }
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);

        m_Pass?.Dispose();
        m_Pass = null;

        m_WaterColorWithoutReflectionPass?.Dispose();
        m_WaterColorWithoutReflectionPass = null;
    }

    // ============================================================================================
    // Pass: Water Color Without Reflection
    // ============================================================================================
    private sealed class WaterColorWithoutReflectionPass : ScriptableRenderPass
    {
        private const string k_ProfilerTag = "M_WaterColorWithoutReflection";
        private readonly ProfilingSampler m_ProfilingSampler = new ProfilingSampler(k_ProfilerTag);

        private const RenderPassEvent k_RenderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        private const string k_LightModeTag = "WaterColorWithoutReflection";
        private const string k_GlobalTextureName = "_WaterColorWithoutReflectionTexture";
        private const string k_RenderTargetName = "_M_WaterColorWithoutReflectionTexture";

        private static readonly int k_GlobalTextureId = Shader.PropertyToID(k_GlobalTextureName);
        private static readonly ShaderTagId k_ShaderTagId = new ShaderTagId(k_LightModeTag);

        private RTHandle m_CameraDepth;
        private RTHandle m_WaterColorWithoutReflectionRT;

        private readonly FilteringSettings m_FilteringSettings = new FilteringSettings(RenderQueueRange.all);
        private readonly RenderStateBlock m_RenderStateBlock;

        public WaterColorWithoutReflectionPass()
        {
            renderPassEvent = k_RenderPassEvent;

            m_RenderStateBlock = new RenderStateBlock(RenderStateMask.Depth)
            {
                depthState = new DepthState(writeEnabled: false, compareFunction: CompareFunction.LessEqual)
            };
        }

        public void Setup(RTHandle cameraDepth)
        {
            m_CameraDepth = cameraDepth;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            var desc = renderingData.cameraData.cameraTargetDescriptor;
            desc.colorFormat = RenderTextureFormat.ARGB32;
            desc.depthBufferBits = 0;

            RenderingUtils.ReAllocateIfNeeded(
                ref m_WaterColorWithoutReflectionRT,
                desc,
                FilterMode.Bilinear,
                TextureWrapMode.Clamp,
                name: k_RenderTargetName
            );

            ConfigureTarget(m_WaterColorWithoutReflectionRT, m_CameraDepth);
            ConfigureClear(ClearFlag.Color, Color.clear);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get(k_ProfilerTag);

            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                CoreUtils.SetRenderTarget(
                    cmd,
                    m_WaterColorWithoutReflectionRT,
                    m_CameraDepth,
                    ClearFlag.Color,
                    Color.clear
                );

                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                var drawingSettings = CreateDrawingSettings(
                    k_ShaderTagId,
                    ref renderingData,
                    SortingCriteria.CommonTransparent
                );

                var filteringSettings = m_FilteringSettings;
                var renderStateBlock = m_RenderStateBlock;

                context.DrawRenderers(
                    renderingData.cullResults,
                    ref drawingSettings,
                    ref filteringSettings,
                    ref renderStateBlock
                );

                cmd.SetGlobalTexture(k_GlobalTextureId, m_WaterColorWithoutReflectionRT);
            }

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

        public void Dispose()
        {
            m_WaterColorWithoutReflectionRT?.Release();
            m_WaterColorWithoutReflectionRT = null;

            m_CameraDepth = null;
        }
    }

    // ============================================================================================
    // Pass: Water SSR (+ Gaussian Blur on _ScreenSpaceReflectionTexture)
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

        // GaussianBlur shader params
        private static readonly int k_BlurSizeId = Shader.PropertyToID("_BlurSize");

        private static readonly string k_KwSimpleVS = "SIMPLE_VS";
        private static readonly string k_KwBinarySearchVS = "BINARY_SEARCH_VS";
        private static readonly string k_KwBinarySearchJitterVS = "BINARY_SEARCH_JITTER_VS";

        private readonly int m_ReflectionTexId;

        private Material m_SsrMaterial;
        private Material m_BlurMaterial;

        private RTHandle m_CameraColor;

        // Final reflection texture (blurred/unblurred) that will be exposed as _ScreenSpaceReflectionTexture
        private RTHandle m_ReflectionRT;

        // Ping-pong temp for blur
        private RTHandle m_BlurTempRT;

        public WaterSSRPass(Settings settings)
        {
            m_ReflectionTexId = Shader.PropertyToID(settings.reflectionTexName);

            Shader ssrShader = Shader.Find("URP/PostProcessing/WaterScreenSpaceReflection");
            if (ssrShader != null)
                m_SsrMaterial = CoreUtils.CreateEngineMaterial(ssrShader);

            Shader blurShader = Shader.Find("URP/PostProcessing/GaussianBlur");
            if (blurShader != null)
                m_BlurMaterial = CoreUtils.CreateEngineMaterial(blurShader);

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

            // Post-process temp RTs: avoid MSAA RTs (must be sampleable)
            desc.msaaSamples = 1;
            desc.bindMS = false;

            RenderingUtils.ReAllocateIfNeeded(
                ref m_ReflectionRT,
                desc,
                FilterMode.Bilinear,
                TextureWrapMode.Clamp,
                name: "_M_WaterSSR_Reflection"
            );

            RenderingUtils.ReAllocateIfNeeded(
                ref m_BlurTempRT,
                desc,
                FilterMode.Bilinear,
                TextureWrapMode.Clamp,
                name: "_M_WaterSSR_BlurTemp"
            );
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (m_SsrMaterial == null)
                return;

            var stack = VolumeManager.instance.stack;
            var volume = stack.GetComponent<ScreenSpaceReflectionVolume>();

            if (!volume.EnableReflection.value)
                return;

            var mode = (ScreenSpaceReflectionType)volume.ScreenSpaceReflectionMode.value;

            DisableAllKeywords();

            switch (mode)
            {
                case ScreenSpaceReflectionType.Simple_ViewSpace:
                    m_SsrMaterial.EnableKeyword(k_KwSimpleVS);
                    break;

                case ScreenSpaceReflectionType.BinarySearch_ViewSpace:
                    m_SsrMaterial.EnableKeyword(k_KwBinarySearchVS);
                    break;

                case ScreenSpaceReflectionType.BinarySearch_Jitter_ViewSpace:
                    m_SsrMaterial.EnableKeyword(k_KwBinarySearchJitterVS);
                    break;
            }

            // SSR params
            m_SsrMaterial.SetColor(k_BaseColorId, volume.ColorChange.value);
            m_SsrMaterial.SetFloat(k_StepLengthId, volume.StepLength.value);
            m_SsrMaterial.SetFloat(k_ThicknessId, volume.Thickness.value);
            m_SsrMaterial.SetFloat(k_MaxStepLengthId, volume.MaxStepLength.value);
            m_SsrMaterial.SetFloat(k_MinDistanceId, volume.MinDistance.value);
            m_SsrMaterial.SetFloat(k_MaxReflectLengthId, volume.MaxReflectLength.value);
            m_SsrMaterial.SetInt(k_DeltaPixelId, volume.DeltaPixel.value);
            m_SsrMaterial.SetFloat(k_DitherIntensityId, volume.DitherIntensity.value);

            float blurSize = volume.BlurSize.value;

            var cmd = CommandBufferPool.Get(k_ProfilerTag);

            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                // 1) SSR -> m_ReflectionRT
                Blitter.BlitCameraTexture(cmd, m_CameraColor, m_ReflectionRT, m_SsrMaterial, 0);

                // 2) Optional Gaussian blur on reflection texture
                if (blurSize > 0f && m_BlurMaterial != null)
                {
                    // Keep blur neutral (no tint); GaussianBlur shader still expects _BaseColor
                    m_BlurMaterial.SetColor(k_BaseColorId, Color.white);
                    m_BlurMaterial.SetFloat(k_BlurSizeId, blurSize);

                    // pass0: reflection -> blurTemp
                    Blitter.BlitCameraTexture(cmd, m_ReflectionRT, m_BlurTempRT, m_BlurMaterial, 0);

                    // pass1: blurTemp -> reflection (final)
                    Blitter.BlitCameraTexture(cmd, m_BlurTempRT, m_ReflectionRT, m_BlurMaterial, 1);
                }

                if (volume.ShowReflectionTexture.value)
                {
                    // Debug view: display (blurred) reflection texture
                    Blitter.BlitCameraTexture(cmd, m_ReflectionRT, m_CameraColor);
                }
                else
                {
                    // Provide (blurred) reflection texture to later shaders
                    cmd.SetGlobalTexture(m_ReflectionTexId, m_ReflectionRT);
                }
            }

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

        private void DisableAllKeywords()
        {
            m_SsrMaterial.DisableKeyword(k_KwSimpleVS);
            m_SsrMaterial.DisableKeyword(k_KwBinarySearchVS);
            m_SsrMaterial.DisableKeyword(k_KwBinarySearchJitterVS);
        }

        public void Dispose()
        {
            m_ReflectionRT?.Release();
            m_ReflectionRT = null;

            m_BlurTempRT?.Release();
            m_BlurTempRT = null;

            CoreUtils.Destroy(m_SsrMaterial);
            m_SsrMaterial = null;

            CoreUtils.Destroy(m_BlurMaterial);
            m_BlurMaterial = null;
        }
    }
    
    private static bool ShouldSkip(in RenderingData renderingData)
    {
        var cameraData = renderingData.cameraData;

        // 只允许 Game / SceneView，相机一律跳过（Preview / Reflection / etc.）
        if (cameraData.cameraType != CameraType.Game &&
            cameraData.cameraType != CameraType.SceneView)
            return true;

        // Overlay 相机跳过（避免叠加相机带来的 RT / Depth 绑定问题）
        if (cameraData.renderType == CameraRenderType.Overlay)
            return true;

        return false;
    }

}
