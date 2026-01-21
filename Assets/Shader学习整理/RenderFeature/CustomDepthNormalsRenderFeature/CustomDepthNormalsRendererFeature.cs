using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public sealed class CustomDepthNormalsRendererFeature : ScriptableRendererFeature
{
    public enum QueueRange
    {
        OpaqueOnly,
        All
    }

    [System.Serializable]
    public sealed class Settings
    {
        [Header("When")]
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingPrePasses;

        [Header("What")]
        public LayerMask layerMask = ~0;
        public QueueRange queueRange = QueueRange.OpaqueOnly;

        [Header("Output (Global Texture Names)")]
        public string depthTextureName = "_m_CameraDepthTexture";
        public string normalsTextureName = "_m_CameraNormalsTexture";

        [Header("Formats")]
        public GraphicsFormat normalsFormat = GraphicsFormat.R16G16B16A16_SNorm;

        public enum DepthBits
        {
            Depth16 = 16,
            Depth32 = 32
        }

        [Tooltip("Depth RT precision. Choose 16 or 32 to avoid invalid values.")]
        public DepthBits depthBits = DepthBits.Depth32;

        [Header("Cameras")]
        [Tooltip("Usually you only want this on Base camera, otherwise camera stack overlays will overwrite globals.")]
        public bool baseCameraOnly = true;
    }

    [SerializeField] private Settings settings = new Settings();

    private RTHandle m_DepthRT;
    private RTHandle m_NormalsRT;

    private int m_DepthTexId;
    private int m_NormalsTexId;

    private DepthNormalsPass m_DepthNormalsPass;

    public override void Create()
    {
        m_DepthTexId = Shader.PropertyToID(settings.depthTextureName);
        m_NormalsTexId = Shader.PropertyToID(settings.normalsTextureName);

        m_DepthNormalsPass = new DepthNormalsPass(settings, m_DepthTexId, m_NormalsTexId)
        {
            renderPassEvent = settings.renderPassEvent
        };
    }

    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        if (ShouldSkip(renderingData))
            return;

        AllocateTargets(in renderingData);
        m_DepthNormalsPass.Setup(normals: m_NormalsRT, depth: m_DepthRT);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (ShouldSkip(renderingData))
            return;

        renderer.EnqueuePass(m_DepthNormalsPass);
    }

    protected override void Dispose(bool disposing)
    {
        m_DepthRT?.Release();
        m_DepthRT = null;

        m_NormalsRT?.Release();
        m_NormalsRT = null;
        
        m_DepthNormalsPass = null;
    }

    private bool ShouldSkip(RenderingData renderingData)
    {
        var camData = renderingData.cameraData;

        //  Skip preview cameras.
        if (camData.cameraType == CameraType.Preview)
            return true;

        if (settings.baseCameraOnly && camData.renderType != CameraRenderType.Base)
            return true;

        return false;
    }

    private void AllocateTargets(in RenderingData renderingData)
    {
        var camDesc = renderingData.cameraData.cameraTargetDescriptor;

        // Depth RT (depth attachment, sample-able)
        var depthDesc = camDesc;
        depthDesc.msaaSamples = 1;
        depthDesc.bindMS = false;
        depthDesc.depthBufferBits = (int)settings.depthBits;
        depthDesc.colorFormat = RenderTextureFormat.Depth;
        depthDesc.graphicsFormat = GraphicsFormat.None;
        depthDesc.sRGB = false;

        RenderingUtils.ReAllocateIfNeeded(ref m_DepthRT, depthDesc);

        // Normals RT (color attachment)
        var normalsDesc = camDesc;
        normalsDesc.msaaSamples = 1;
        normalsDesc.bindMS = false;
        normalsDesc.depthBufferBits = 0;
        normalsDesc.graphicsFormat = settings.normalsFormat;
        normalsDesc.sRGB = false;

        RenderingUtils.ReAllocateIfNeeded(ref m_NormalsRT, normalsDesc);
    }
    
    
    private sealed class DepthNormalsPass : ScriptableRenderPass
    {
        private static readonly ShaderTagId k_ShaderTag = new ShaderTagId("DepthNormals");

        private const string ProfilerTag = "M_CustomDepthNormalsPass";
        private readonly ProfilingSampler m_ProfilingSampler = new ProfilingSampler(ProfilerTag);

        private readonly FilteringSettings m_Filtering;
        private readonly int m_GlobalDepthTexId;
        private readonly int m_GlobalNormalsTexId;

        private RTHandle m_Normals;
        private RTHandle m_Depth;

        public DepthNormalsPass(Settings settings, int globalDepthTexId, int globalNormalsTexId)
        {
            var queue = (settings.queueRange == QueueRange.OpaqueOnly)
                ? RenderQueueRange.opaque
                : RenderQueueRange.all;

            m_Filtering = new FilteringSettings(queue, settings.layerMask);

            m_GlobalDepthTexId = globalDepthTexId;
            m_GlobalNormalsTexId = globalNormalsTexId;

            ConfigureInput(ScriptableRenderPassInput.None);
        }

        public void Setup(RTHandle normals, RTHandle depth)
        {
            m_Normals = normals;
            m_Depth = depth;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            ConfigureTarget(m_Normals, m_Depth);

            // 清除法线和深度数据避免出现错误
            ConfigureClear(ClearFlag.Color | ClearFlag.Depth, Color.black);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get(ProfilerTag);

            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                var sorting = renderingData.cameraData.defaultOpaqueSortFlags;
                var drawing = CreateDrawingSettings(k_ShaderTag, ref renderingData, sorting);

                var rsb = new RenderStateBlock(RenderStateMask.Depth)
                {
                    depthState = new DepthState(true, CompareFunction.LessEqual)
                };

                // readonly field cannot be passed by ref -> local copy
                var filtering = m_Filtering;
                context.DrawRenderers(renderingData.cullResults, ref drawing, ref filtering, ref rsb);

                cmd.SetGlobalTexture(m_GlobalDepthTexId, m_Depth);
                cmd.SetGlobalTexture(m_GlobalNormalsTexId, m_Normals);
            }

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }
        
    }
}
