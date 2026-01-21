using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public sealed class PerObjectShadowFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public sealed class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;

        [Header("Shader & Globals")]
        public string atlasTexName = "_CharacterShadowAtlas";
        public string matrixArrayName = "_CharacterShadowMatrix";
        public string uvClampArrayName = "_CharacterUVClamp";
        public string countName = "_CharacterShadowCount";

        [Header("Culling Settings")]
        public bool enableBackfaceShadowMapping = false;
        public LayerMask hideLayerMask;
        public float maxDistance = 35f;
        [Range(1, 9)] public int maxTargets = 9;

        [Header("Atlas Settings")]
        public int shadowAtlasSize = 2048;
        public int shadowAtlasTileBorderPixels = 2;

        [Header("Light Camera Settings")]
        public float lightCameraBackDistance = 10f;
        public float depthPadding = 0.5f;
        public float xyPadding = 0.2f;

        [Header("Bias Settings")]
        [Range(0.0f, 0.2f)] public float depthBias = 0.005f;
        [Range(0.0f, 1.0f)] public float normalBias = 0.05f;
    }

    [SerializeField] public Settings settings = new Settings();

    private RTHandle m_ShadowAtlasRT;
    private PerObjectShadowPass m_Pass;

    // Global IDs
    private int m_IdAtlas;
    private int m_IdMatArr;
    private int m_IdUVArr;
    private int m_IdCount;
    private int m_IdPerObjectShadowBias;
    private int m_IdDepthRanges;

    public override void Create()
    {
        CachePropertyIds();

        m_Pass = new PerObjectShadowPass(
            settings,
            m_IdAtlas,
            m_IdMatArr,
            m_IdUVArr,
            m_IdCount,
            m_IdPerObjectShadowBias,
            m_IdDepthRanges)
        {
            renderPassEvent = settings.renderPassEvent
        };
    }

    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        if (ShouldSkip(in renderingData))
            return;

        AllocateAtlas();
        m_Pass.Setup(m_ShadowAtlasRT);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (ShouldSkip(in renderingData))
            return;

        var sys = PerObjectShadowSystem.Instance;
        if (sys == null)
            return;

        // Sync settings into system (tile layout, ranges, etc.)
        sys.ApplySettings(settings);

        if (sys.ActiveCount > 0)
            renderer.EnqueuePass(m_Pass);
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);

        m_ShadowAtlasRT?.Release();
        m_ShadowAtlasRT = null;

        m_Pass = null;
    }

    private bool ShouldSkip(in RenderingData renderingData)
    {
        var camData = renderingData.cameraData;

        // Skip editor preview cameras
        if (camData.cameraType == CameraType.Preview)
            return true;

        // Skip overlay cameras (avoid overwriting globals / double work)
        if (camData.renderType == CameraRenderType.Overlay)
            return true;

        return false;
    }

    private void CachePropertyIds()
    {
        m_IdAtlas = Shader.PropertyToID(settings.atlasTexName);
        m_IdMatArr = Shader.PropertyToID(settings.matrixArrayName);
        m_IdUVArr = Shader.PropertyToID(settings.uvClampArrayName);
        m_IdCount = Shader.PropertyToID(settings.countName);
        m_IdPerObjectShadowBias = Shader.PropertyToID("_PerObjectShadowBias");
        m_IdDepthRanges = Shader.PropertyToID("_DepthRanges");
    }

    private void AllocateAtlas()
    {
        var desc = new RenderTextureDescriptor(
            settings.shadowAtlasSize,
            settings.shadowAtlasSize,
            RenderTextureFormat.Shadowmap,
            32)
        {
            msaaSamples = 1,
            useMipMap = false,
            autoGenerateMips = false,
            sRGB = false
        };

        RenderingUtils.ReAllocateIfNeeded(
            ref m_ShadowAtlasRT,
            desc,
            FilterMode.Point,
            TextureWrapMode.Clamp,
            name: "_CharacterShadowAtlasRT"
        );
    }

    // ============================================================================================
    // Pass
    // ============================================================================================
    private sealed class PerObjectShadowPass : ScriptableRenderPass
    {
        private const string k_ProfilerTag = "M_PerObjectShadowPass";
        private readonly ProfilingSampler m_ProfilingSampler = new ProfilingSampler(k_ProfilerTag);

        // Unity ShadowCaster expects this global in some shaders
        private static readonly int k_IdShadowBias = Shader.PropertyToID("_ShadowBias");

        private readonly Settings m_Settings;

        private readonly int m_IdAtlas;
        private readonly int m_IdMatArr;
        private readonly int m_IdUVArr;
        private readonly int m_IdCount;
        private readonly int m_IdPerObjectShadowBias;
        private readonly int m_IdDepthRanges;

        private RTHandle m_ShadowAtlasRT;

        public PerObjectShadowPass(
            Settings settings,
            int idAtlas,
            int idMatArr,
            int idUVArr,
            int idCount,
            int idPerObjectShadowBias,
            int idDepthRanges)
        {
            m_Settings = settings;

            m_IdAtlas = idAtlas;
            m_IdMatArr = idMatArr;
            m_IdUVArr = idUVArr;
            m_IdCount = idCount;
            m_IdPerObjectShadowBias = idPerObjectShadowBias;
            m_IdDepthRanges = idDepthRanges;

            ConfigureInput(ScriptableRenderPassInput.None);
        }

        public void Setup(RTHandle shadowAtlas)
        {
            m_ShadowAtlasRT = shadowAtlas;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            if (m_ShadowAtlasRT == null)
                return;

            ConfigureTarget(m_ShadowAtlasRT);
            ConfigureClear(ClearFlag.Depth, Color.clear);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var sys = PerObjectShadowSystem.Instance;
            if (sys == null || sys.ActiveCount <= 0)
                return;

            int count = sys.ActiveCount;

            // Bias: depth positive, normal negative (shrinks)
            float depthBias = m_Settings.depthBias;
            float normalBias = -m_Settings.normalBias;
            Vector4 shadowBias = new Vector4(depthBias, normalBias, 0f, 0f);

            bool invertCulling = m_Settings.enableBackfaceShadowMapping;

            var cmd = CommandBufferPool.Get(k_ProfilerTag);
            try
            {
                using (new ProfilingScope(cmd, m_ProfilingSampler))
                {
                    // Clear atlas once
                    cmd.SetRenderTarget(m_ShadowAtlasRT);
                    cmd.ClearRenderTarget(true, false, Color.clear);

                    // Globals (set once)
                    cmd.SetGlobalTexture(m_IdAtlas, m_ShadowAtlasRT);
                    cmd.SetGlobalInt(m_IdCount, count);
                    cmd.SetGlobalMatrixArray(m_IdMatArr, sys.WorldToShadowAtlasMatrices);
                    cmd.SetGlobalVectorArray(m_IdUVArr, sys.UVClamp);
                    cmd.SetGlobalVector(m_IdPerObjectShadowBias, new Vector4(depthBias, normalBias, 0, 0));
                    cmd.SetGlobalVectorArray(m_IdDepthRanges, sys.DepthRanges);

                    // Some ShadowCaster code paths use this
                    cmd.SetGlobalVector(k_IdShadowBias, shadowBias);

                    // Culling mode (set once)
                    cmd.SetInvertCulling(invertCulling);

                    for (int i = 0; i < count; i++)
                    {
                        Rect tileViewport = sys.TileViewport[i];

                        cmd.SetViewport(tileViewport);
                        cmd.EnableScissorRect(tileViewport);

                        cmd.SetViewProjectionMatrices(sys.ViewMatrices[i], sys.ProjMatrices[i]);

                        DrawGroup(cmd, sys.GetActiveGroup(i));

                        cmd.DisableScissorRect();
                    }

                    // Restore
                    cmd.SetInvertCulling(false);
                }

                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                // Restore camera state for following passes
                context.SetupCameraProperties(renderingData.cameraData.camera);
            }
            finally
            {
                CommandBufferPool.Release(cmd);
            }
        }

        private static void DrawGroup(CommandBuffer cmd, PerObjectShadowSystem.RendererGroup group)
        {
            if (group == null || group.renderers == null)
                return;

            for (int rIdx = 0; rIdx < group.renderers.Count; rIdx++)
            {
                Renderer r = group.renderers[rIdx];
                if (r == null || !r.enabled || !r.gameObject.activeInHierarchy)
                    continue;

                Material[] mats = r.sharedMaterials;
                if (mats == null || mats.Length == 0)
                    continue;

                int subMeshCount = GetSafeSubMeshCount(r);
                int drawCount = Mathf.Min(mats.Length, subMeshCount);

                for (int sub = 0; sub < drawCount; sub++)
                {
                    Material mat = mats[sub];
                    if (mat == null)
                        continue;

                    int passIndex = mat.FindPass("ShadowCaster");
                    if (passIndex >= 0)
                        cmd.DrawRenderer(r, mat, sub, passIndex);
                }
            }
        }

        private static int GetSafeSubMeshCount(Renderer r)
        {
            if (r is SkinnedMeshRenderer sk && sk.sharedMesh != null)
                return sk.sharedMesh.subMeshCount;

            if (r is MeshRenderer mr)
            {
                MeshFilter mf = mr.GetComponent<MeshFilter>();
                if (mf != null && mf.sharedMesh != null)
                    return mf.sharedMesh.subMeshCount;
            }

            return 1;
        }
    }
}
