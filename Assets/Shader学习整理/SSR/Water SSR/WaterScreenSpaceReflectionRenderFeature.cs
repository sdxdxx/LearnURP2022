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
        if (!ShouldSkip(in renderingData))
            m_Pass.Setup(renderer.cameraColorTargetHandle, renderer.cameraDepthTargetHandle);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (!ShouldSkip(in renderingData))
            renderer.EnqueuePass(m_Pass);
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        m_Pass?.Dispose();
        m_Pass = null;
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

        private static readonly int k_BlurSizeId = Shader.PropertyToID("_BlurSize");

        private static readonly string k_KwSimpleVS = "SIMPLE_VS";
        private static readonly string k_KwBinarySearchVS = "BINARY_SEARCH_VS";
        private static readonly string k_KwBinarySearchJitterVS = "BINARY_SEARCH_JITTER_VS";

        // Water overlay (LightMode)
        private const string k_WaterLightModeTag = "WaterColorWithoutReflection";
        private static readonly ShaderTagId k_WaterShaderTagId = new ShaderTagId(k_WaterLightModeTag);

        private readonly int m_ReflectionTexId;

        private Material m_SsrMaterial;
        private Material m_BlurMaterial;

        private RTHandle m_CameraColor;
        private RTHandle m_CameraDepth;

        // Input for SSR (sampleable, msaa=1): cameraColor copied + water overlaid (no reflection)
        private RTHandle m_SampleTempRT;

        // For depth-tested water overlay when camera uses MSAA (>1). Must match camera MSAA.
        private RTHandle m_SampleMsaaRT;

        private RTHandle m_ReflectionRT;
        private RTHandle m_BlurTempRT;

        private readonly FilteringSettings m_WaterFilteringSettings = new FilteringSettings(RenderQueueRange.all);
        private readonly RenderStateBlock m_WaterRenderStateBlock;

        public WaterSSRPass(Settings settings)
        {
            m_ReflectionTexId = Shader.PropertyToID(settings.reflectionTexName);

            Shader ssrShader = Shader.Find("URP/PostProcessing/WaterScreenSpaceReflection");
            if (ssrShader != null)
                m_SsrMaterial = CoreUtils.CreateEngineMaterial(ssrShader);

            Shader blurShader = Shader.Find("URP/PostProcessing/GaussianBlur");
            if (blurShader != null)
                m_BlurMaterial = CoreUtils.CreateEngineMaterial(blurShader);

            m_WaterRenderStateBlock = new RenderStateBlock(RenderStateMask.Depth)
            {
                depthState = new DepthState(writeEnabled: false, compareFunction: CompareFunction.LessEqual)
            };

            ConfigureInput(ScriptableRenderPassInput.Color);
        }

        public void Setup(RTHandle cameraColor, RTHandle cameraDepth)
        {
            m_CameraColor = cameraColor;
            m_CameraDepth = cameraDepth;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            ConfigureTarget(m_CameraColor);

            var cameraDesc = renderingData.cameraData.cameraTargetDescriptor;
            cameraDesc.depthBufferBits = 0;

            // 1) SSR input sample RT (must be sampleable)
            var sampleDesc = cameraDesc;
            sampleDesc.msaaSamples = 1;
            sampleDesc.bindMS = false;

            RenderingUtils.ReAllocateIfNeeded(
                ref m_SampleTempRT,
                sampleDesc,
                FilterMode.Bilinear,
                TextureWrapMode.Clamp,
                name: "_M_WaterSSR_SampleTemp"
            );

            // 2) MSAA overlay RT (only needed if camera uses MSAA and we bind camera depth)
            int cameraMsaaSamples = renderingData.cameraData.cameraTargetDescriptor.msaaSamples;
            if (cameraMsaaSamples > 1)
            {
                var msaaDesc = cameraDesc;
                msaaDesc.msaaSamples = cameraMsaaSamples;
                msaaDesc.bindMS = false; // renderbuffer style; we only need it as RT source for resolve blit

                RenderingUtils.ReAllocateIfNeeded(
                    ref m_SampleMsaaRT,
                    msaaDesc,
                    FilterMode.Bilinear,
                    TextureWrapMode.Clamp,
                    name: "_M_WaterSSR_SampleMSAA"
                );
            }
            else
            {
                m_SampleMsaaRT?.Release();
                m_SampleMsaaRT = null;
            }

            // 3) Post-process RTs for reflection + blur (sampleable)
            var postDesc = cameraDesc;
            postDesc.msaaSamples = 1;
            postDesc.bindMS = false;

            RenderingUtils.ReAllocateIfNeeded(
                ref m_ReflectionRT,
                postDesc,
                FilterMode.Bilinear,
                TextureWrapMode.Clamp,
                name: "_M_WaterSSR_Reflection"
            );

            RenderingUtils.ReAllocateIfNeeded(
                ref m_BlurTempRT,
                postDesc,
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

            var cmd = CommandBufferPool.Get(k_ProfilerTag);

            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                // ----------------------------------------------------------------------------------
                // A) Build SSR input: cameraColor copy + water overlay (depth test, no depth write)
                // ----------------------------------------------------------------------------------
                int cameraMsaaSamples = renderingData.cameraData.cameraTargetDescriptor.msaaSamples;
                RTHandle overlayTarget = cameraMsaaSamples > 1 ? m_SampleMsaaRT : m_SampleTempRT;

                // Copy camera color to target (full-screen)
                Blitter.BlitCameraTexture(cmd, m_CameraColor, overlayTarget);

                // Draw water (LightMode=WaterColorWithoutReflection) onto overlayTarget using camera depth
                DrawWaterColorWithoutReflection(cmd, context, ref renderingData, overlayTarget);

                // Resolve to sampleable RT if needed
                if (overlayTarget != m_SampleTempRT)
                    Blitter.BlitCameraTexture(cmd, overlayTarget, m_SampleTempRT);

                // ----------------------------------------------------------------------------------
                // B) SSR keyword + parameters
                // ----------------------------------------------------------------------------------
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

                m_SsrMaterial.SetColor(k_BaseColorId, volume.ColorChange.value);
                m_SsrMaterial.SetFloat(k_StepLengthId, volume.StepLength.value);
                m_SsrMaterial.SetFloat(k_ThicknessId, volume.Thickness.value);
                m_SsrMaterial.SetFloat(k_MaxStepLengthId, volume.MaxStepLength.value);
                m_SsrMaterial.SetFloat(k_MinDistanceId, volume.MinDistance.value);
                m_SsrMaterial.SetFloat(k_MaxReflectLengthId, volume.MaxReflectLength.value);
                m_SsrMaterial.SetInt(k_DeltaPixelId, volume.DeltaPixel.value);
                m_SsrMaterial.SetFloat(k_DitherIntensityId, volume.DitherIntensity.value);

                float blurSize = volume.BlurSize.value;

                // ----------------------------------------------------------------------------------
                // C) SSR: m_SampleTempRT -> m_ReflectionRT
                // ----------------------------------------------------------------------------------
                Blitter.BlitCameraTexture(cmd, m_SampleTempRT, m_ReflectionRT, m_SsrMaterial, 0);

                // Optional blur
                if (blurSize > 0f && m_BlurMaterial != null)
                {
                    m_BlurMaterial.SetColor(k_BaseColorId, Color.white);
                    m_BlurMaterial.SetFloat(k_BlurSizeId, blurSize);

                    Blitter.BlitCameraTexture(cmd, m_ReflectionRT, m_BlurTempRT, m_BlurMaterial, 0);
                    Blitter.BlitCameraTexture(cmd, m_BlurTempRT, m_ReflectionRT, m_BlurMaterial, 1);
                }

                // Debug / bind global
                if (volume.ShowReflectionTexture.value)
                {
                    Blitter.BlitCameraTexture(cmd, m_ReflectionRT, m_CameraColor);
                }
                else
                {
                    cmd.SetGlobalTexture(m_ReflectionTexId, m_ReflectionRT);
                }
            }

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

        private void DrawWaterColorWithoutReflection(
            CommandBuffer cmd,
            ScriptableRenderContext context,
            ref RenderingData renderingData,
            RTHandle colorTarget)
        {
            // Bind color + camera depth; do NOT clear (we want the copied cameraColor as background)
            CoreUtils.SetRenderTarget(cmd, colorTarget, m_CameraDepth, ClearFlag.None);

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            var drawingSettings = CreateDrawingSettings(
                k_WaterShaderTagId,
                ref renderingData,
                SortingCriteria.CommonTransparent
            );

            // readonly 字段不能 ref 传参：用局部副本
            var filteringSettings = m_WaterFilteringSettings;
            var renderStateBlock = m_WaterRenderStateBlock;

            context.DrawRenderers(
                renderingData.cullResults,
                ref drawingSettings,
                ref filteringSettings,
                ref renderStateBlock
            );
        }

        private void DisableAllKeywords()
        {
            m_SsrMaterial.DisableKeyword(k_KwSimpleVS);
            m_SsrMaterial.DisableKeyword(k_KwBinarySearchVS);
            m_SsrMaterial.DisableKeyword(k_KwBinarySearchJitterVS);
        }

        public void Dispose()
        {
            m_SampleTempRT?.Release();
            m_SampleTempRT = null;

            m_SampleMsaaRT?.Release();
            m_SampleMsaaRT = null;

            m_ReflectionRT?.Release();
            m_ReflectionRT = null;

            m_BlurTempRT?.Release();
            m_BlurTempRT = null;

            CoreUtils.Destroy(m_SsrMaterial);
            m_SsrMaterial = null;

            CoreUtils.Destroy(m_BlurMaterial);
            m_BlurMaterial = null;

            m_CameraColor = null;
            m_CameraDepth = null;
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
