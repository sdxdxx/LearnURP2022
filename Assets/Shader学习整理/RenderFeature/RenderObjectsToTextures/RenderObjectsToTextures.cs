using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public sealed class RenderObjectsToTextures : ScriptableRendererFeature
{
    [System.Serializable]
    public sealed class TargetSetting
    {
        [Tooltip("Shader LightMode Tag")]
        public string lightModeTag = "RenderMask";

        [Tooltip("Global texture name")]
        public string textureName = "_MaskTex";

        [Tooltip("R8 for masks; Default/RGBA for color content")]
        public RenderTextureFormat textureFormat = RenderTextureFormat.R8;
    }

    [System.Serializable]
    public sealed class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;

        [Header("Filters")]
        public RenderQueueType renderQueueType = RenderQueueType.Opaque;
        public LayerMask layerMask = -1;

        [Header("Global Settings")]
        [Range(1, 4)] public int downSample = 1;

        [Header("Targets")]
        public List<TargetSetting> renderTargets = new List<TargetSetting>();
    }

    public Settings settings = new Settings();

    private RenderObjectsToTexturesPass m_Pass;

    public override void Create()
    {
        m_Pass = new RenderObjectsToTexturesPass(this.name, settings)
        {
            renderPassEvent = settings.renderPassEvent
        };
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

    private bool ShouldSkip(in RenderingData renderingData)
    {
        CameraType cameraType = renderingData.cameraData.cameraType;
        if (cameraType != CameraType.Game && cameraType != CameraType.SceneView)
            return true;

        if (renderingData.cameraData.renderType == CameraRenderType.Overlay)
            return true;

        if (settings.renderTargets == null || settings.renderTargets.Count == 0)
            return true;

        return false;
    }

    // ============================================================================================
    // Pass
    // ============================================================================================
    private sealed class RenderObjectsToTexturesPass : ScriptableRenderPass
    {
        private readonly Settings m_Settings;

        private readonly string m_ProfilerTag;
        private readonly ProfilingSampler m_ProfilingSampler;

        private FilteringSettings m_FilteringSettings;
        private RenderStateBlock m_RenderStateBlock;

        private readonly Dictionary<string, RTHandle> m_ColorRenderTargetHandlesByName = new Dictionary<string, RTHandle>();
        private RTHandle m_SharedDepthRenderTargetHandle;

        public RenderObjectsToTexturesPass(string featureName, Settings settings)
        {
            m_ProfilerTag = featureName;                  // 多实例区分：必须保留
            m_ProfilingSampler = new ProfilingSampler(featureName);

            m_Settings = settings;

            RenderQueueRange queueRange = (m_Settings.renderQueueType == RenderQueueType.Transparent)
                ? RenderQueueRange.transparent
                : RenderQueueRange.opaque;

            m_FilteringSettings = new FilteringSettings(queueRange, m_Settings.layerMask);
            m_RenderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(m_ProfilerTag);

            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
            desc.msaaSamples = 1;
            desc.width /= m_Settings.downSample;
            desc.height /= m_Settings.downSample;

            RenderTextureDescriptor depthDescriptor = desc;
            depthDescriptor.colorFormat = RenderTextureFormat.Depth;
            depthDescriptor.depthBufferBits = 32;
            RenderingUtils.ReAllocateIfNeeded(ref m_SharedDepthRenderTargetHandle, depthDescriptor, name: "_SharedDepthTex");

            SortingCriteria sortingCriteria = (m_Settings.renderQueueType == RenderQueueType.Transparent)
                ? SortingCriteria.CommonTransparent
                : renderingData.cameraData.defaultOpaqueSortFlags;

            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                for (int i = 0; i < m_Settings.renderTargets.Count; i++)
                {
                    TargetSetting targetSetting = m_Settings.renderTargets[i];
                    if (string.IsNullOrEmpty(targetSetting.lightModeTag) || string.IsNullOrEmpty(targetSetting.textureName))
                        continue;

                    RenderTextureDescriptor colorDesc = desc;
                    colorDesc.colorFormat = targetSetting.textureFormat;
                    colorDesc.depthBufferBits = 0;

                    m_ColorRenderTargetHandlesByName.TryGetValue(targetSetting.textureName, out RTHandle colorRenderTargetHandle);
                    RenderingUtils.ReAllocateIfNeeded(ref colorRenderTargetHandle, colorDesc, name: targetSetting.textureName);
                    m_ColorRenderTargetHandlesByName[targetSetting.textureName] = colorRenderTargetHandle;

                    CoreUtils.SetRenderTarget(cmd, colorRenderTargetHandle, m_SharedDepthRenderTargetHandle, ClearFlag.All, Color.clear);

                    // 必须 flush：DrawRenderers 不走 cmd，需要先把 RT 状态切到 context
                    context.ExecuteCommandBuffer(cmd);
                    cmd.Clear();

                    DrawingSettings drawingSettings = CreateDrawingSettings(
                        new ShaderTagId(targetSetting.lightModeTag),
                        ref renderingData,
                        sortingCriteria
                    );

                    context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref m_FilteringSettings, ref m_RenderStateBlock);

                    cmd.SetGlobalTexture(Shader.PropertyToID(targetSetting.textureName), colorRenderTargetHandle);
                }
            }

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

        public void Dispose()
        {
            foreach (var dictionaryEntry in m_ColorRenderTargetHandlesByName)
                dictionaryEntry.Value?.Release();

            m_ColorRenderTargetHandlesByName.Clear();

            m_SharedDepthRenderTargetHandle?.Release();
            m_SharedDepthRenderTargetHandle = null;
        }
    }
}
