using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public sealed class LoopRenderPassFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public sealed class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        public RenderQueueType renderQueueType = RenderQueueType.Opaque;
        public LayerMask layerMask = -1;

       
        public List<string> lightModeTags = new List<string>();

        [Range(1, 300)] public int loopTimes = 1;
    }

    [SerializeField] public Settings settings = new Settings();

    private LoopRenderPass m_Pass;

    public override void Create()
    {
        m_Pass = new LoopRenderPass(settings)
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
        m_Pass = null;
    }

    private bool ShouldSkip(in RenderingData renderingData)
    {
        if (renderingData.cameraData.cameraType == CameraType.Preview)
            return true;
        
        if (settings.lightModeTags.Count == 0)
            return true;
        
        return false;
    }

    // ============================================================================================
    // Pass
    // ============================================================================================
    private sealed class LoopRenderPass : ScriptableRenderPass
    {
        private const string k_ProfilerTag = "M_LoopRenderPass";
        private readonly ProfilingSampler m_ProfilingSampler = new ProfilingSampler(k_ProfilerTag);

        private static readonly int k_LoopIndexId = Shader.PropertyToID("_LoopIndex");
        private static readonly int k_LoopTimesId = Shader.PropertyToID("_LoopTimes");

        private readonly Settings m_Settings;

        private readonly List<ShaderTagId> m_ShaderTags = new List<ShaderTagId>();
        private FilteringSettings m_Filtering;

        private readonly SortingCriteria m_SortingCriteria;

        public LoopRenderPass(Settings settings)
        {
            m_Settings = settings;

            BuildShaderTagList(m_Settings.lightModeTags);

            var queue = (m_Settings.renderQueueType == RenderQueueType.Transparent)
                ? RenderQueueRange.transparent
                : RenderQueueRange.opaque;

            m_Filtering = new FilteringSettings(queue, m_Settings.layerMask);

            m_SortingCriteria = (m_Settings.renderQueueType == RenderQueueType.Transparent)
                ? SortingCriteria.CommonTransparent
                : SortingCriteria.CommonOpaque;

            ConfigureInput(ScriptableRenderPassInput.None);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            
            var cmd = CommandBufferPool.Get(k_ProfilerTag);

            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                cmd.SetGlobalInt(k_LoopTimesId, m_Settings.loopTimes);

                // Flush once so GPU sees _LoopTimes before draws.
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                for (int i = 0; i < m_Settings.loopTimes; i++)
                {
                    // Must flush per-iteration so shader reads the correct _LoopIndex.
                    cmd.SetGlobalInt(k_LoopIndexId, i);
                    context.ExecuteCommandBuffer(cmd);
                    cmd.Clear();

                    var drawing = CreateDrawingSettings(m_ShaderTags, ref renderingData, m_SortingCriteria);
                    context.DrawRenderers(renderingData.cullResults, ref drawing, ref m_Filtering);
                }
            }

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

        private void BuildShaderTagList(List<string> tags)
        {
            m_ShaderTags.Clear();

            if (tags == null || tags.Count == 0)
                return;

            for (int i = 0; i < tags.Count; i++)
            {
                string t = tags[i];
                if (!string.IsNullOrEmpty(t))
                    m_ShaderTags.Add(new ShaderTagId(t));
            }
        }
    }
}
