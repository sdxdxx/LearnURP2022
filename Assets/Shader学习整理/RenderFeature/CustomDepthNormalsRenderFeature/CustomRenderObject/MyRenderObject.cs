using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public sealed class MyRenderObject : ScriptableRendererFeature
{
    [System.Serializable]
    public sealed class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        public SortingCriteria sortingCriteria = SortingCriteria.CommonOpaque;

        [Tooltip("If empty, defaults to URP forward tags.")]
        public List<string> shaderTagsList = new List<string>();

        public LayerMask layerMask = ~0;

        [Tooltip("Usually keep true to avoid overlay cameras running the same pass again.")]
        public bool baseCameraOnly = true;
    }

    [SerializeField] private Settings settings = new Settings();

    private MyRenderObjectPass m_Pass;

    public override void Create()
    {
        m_Pass = new MyRenderObjectPass(settings)
        {
            renderPassEvent = settings.renderPassEvent
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (ShouldSkip(ref renderingData))
            return;

        renderer.EnqueuePass(m_Pass);
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        m_Pass = null;
    }

    private bool ShouldSkip(ref RenderingData renderingData)
    {
        var camData = renderingData.cameraData;

        // Skip preview cameras (Inspector/Project preview) to avoid editor pollution.
        if (camData.cameraType == CameraType.Preview)
            return true;

        if (settings.baseCameraOnly && camData.renderType != CameraRenderType.Base)
            return true;

        return false;
    }

    // ============================================================================================
    // Pass
    // ============================================================================================
    private sealed class MyRenderObjectPass : ScriptableRenderPass
    {
        private const string k_ProfilerTag = "M_MyRenderObjectPass";

        private static readonly ShaderTagId k_DefaultTag0 = new ShaderTagId("SRPDefaultUnlit");
        private static readonly ShaderTagId k_DefaultTag1 = new ShaderTagId("UniversalForward");
        private static readonly ShaderTagId k_DefaultTag2 = new ShaderTagId("UniversalForwardOnly");

        private readonly ProfilingSampler m_ProfilingSampler = new ProfilingSampler(k_ProfilerTag);

        private readonly SortingCriteria m_Sorting;
        private readonly List<ShaderTagId> m_ShaderTags = new List<ShaderTagId>(4);

        // FilteringSettings 是 struct；DrawRenderers 需要 ref，因此不要声明成 readonly
        private FilteringSettings m_Filtering;

        public MyRenderObjectPass(Settings settings)
        {
            m_Sorting = settings.sortingCriteria;
            m_Filtering = new FilteringSettings(RenderQueueRange.all, settings.layerMask);

            BuildShaderTagList(settings.shaderTagsList);

            // This pass does not sample camera textures; it only draws renderers.
            ConfigureInput(ScriptableRenderPassInput.None);
        }

        private void BuildShaderTagList(List<string> tagNames)
        {
            m_ShaderTags.Clear();

            if (tagNames != null && tagNames.Count > 0)
            {
                for (int i = 0; i < tagNames.Count; i++)
                {
                    var name = tagNames[i];
                    if (!string.IsNullOrEmpty(name))
                        m_ShaderTags.Add(new ShaderTagId(name));
                }
            }

            if (m_ShaderTags.Count == 0)
            {
                m_ShaderTags.Add(k_DefaultTag0);
                m_ShaderTags.Add(k_DefaultTag1);
                m_ShaderTags.Add(k_DefaultTag2);
            }
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get(k_ProfilerTag);

            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                var drawing = CreateDrawingSettings(m_ShaderTags, ref renderingData, m_Sorting);
                
                context.DrawRenderers(renderingData.cullResults, ref drawing, ref m_Filtering);
            }

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }
    }
}
