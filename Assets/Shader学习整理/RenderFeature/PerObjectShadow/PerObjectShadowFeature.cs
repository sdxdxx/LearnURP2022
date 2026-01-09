using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class PerObjectShadowFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;

        [Header("Shader & Globals")]
        public string atlasTexName = "_CharacterShadowAtlas";
        public string matrixArrayName = "_CharacterShadowMatrix";
        public string uvClampArrayName = "_CharacterUVClamp";
        public string countName = "_CharacterShadowCount";

        [Header("Culling Settings")]
        public bool enableBackfaceShadowMapping = false;//背面阴影映射模式
        public LayerMask hideLayerMask;
        public float maxDistance = 35f;
        // 【优化】范围改为 1-16，刚好对应最大 4x4 的 Atlas 分块
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

    private class CustomRenderPass : ScriptableRenderPass
    {
        private const string ProfilerTag = "PerObjectShadowPass";
        private readonly ProfilingSampler _profilingSampler = new(ProfilerTag);

        private readonly Settings _settings;
        
        private float depthBias = 0;
        private float normalBias = 0;
        
        private RTHandle _shadowAtlasRT;

        private readonly bool enableBackfaceShadowMapping;
        
        private readonly int _idAtlas;
        private readonly int _idMatArr;
        private readonly int _idUVArr;
        private readonly int _idCount;
        private readonly int _idShadowBiasGen;
        

        // IDs for ShadowCasterPass context
        private static readonly int _idShadowBias = Shader.PropertyToID("_ShadowBias");

        public CustomRenderPass(Settings settings)
        {
            _settings = settings;
            enableBackfaceShadowMapping = settings.enableBackfaceShadowMapping;
            _idAtlas = Shader.PropertyToID(_settings.atlasTexName);
            _idMatArr = Shader.PropertyToID(_settings.matrixArrayName);
            _idUVArr = Shader.PropertyToID(_settings.uvClampArrayName);
            _idCount = Shader.PropertyToID(_settings.countName);
            _idShadowBiasGen = Shader.PropertyToID("_PerObjectShadowBiasGen");
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            // Bias 处理：深度正偏，法线负偏(收缩)
            depthBias = _settings.depthBias;
            normalBias = -_settings.normalBias;
            
            var desc = new RenderTextureDescriptor(
                _settings.shadowAtlasSize,
                _settings.shadowAtlasSize,
                RenderTextureFormat.Shadowmap,
                16)
            {
                msaaSamples = 1,
                useMipMap = false,
                autoGenerateMips = false,
                sRGB = false
            };

            RenderingUtils.ReAllocateIfNeeded(
                ref _shadowAtlasRT,
                desc,
                FilterMode.Point,
                TextureWrapMode.Clamp,
                name: "_CharacterShadowAtlasRT"
            );

            ConfigureTarget(_shadowAtlasRT);
            ConfigureClear(ClearFlag.Depth, Color.clear);
        }

        private static Rect GetCameraViewportRect(ref RenderingData renderingData)
        {
            Camera cam = renderingData.cameraData.camera;
            var desc = renderingData.cameraData.cameraTargetDescriptor;
            Rect rect = cam.rect;
            return new Rect(
                rect.x * desc.width,
                rect.y * desc.height,
                rect.width * desc.width,
                rect.height * desc.height
            );
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (renderingData.cameraData.renderType == CameraRenderType.Overlay)
                return;

            var sys = PerObjectShadowSystem.Instance;
            if (sys == null || sys.ActiveCount <= 0)
                return;

            int count = sys.ActiveCount;
            
            CommandBuffer cmd = CommandBufferPool.Get(ProfilerTag);

            try
            {
                using (new ProfilingScope(cmd, _profilingSampler))
                {
                    cmd.SetRenderTarget(_shadowAtlasRT);
                    cmd.ClearRenderTarget(true, false, Color.clear);

                    // 设置 Shader 全局变量
                    cmd.SetGlobalTexture(_idAtlas, _shadowAtlasRT);
                    cmd.SetGlobalInt(_idCount, count);
                    cmd.SetGlobalMatrixArray(_idMatArr, sys.WorldToShadowAtlasMatrices);
                    cmd.SetGlobalVectorArray(_idUVArr, sys.UVClamp);
                    cmd.SetGlobalVector(_idShadowBiasGen, new Vector4(depthBias, normalBias, 0, 0));

                    Vector4 shadowBias = new Vector4(depthBias, normalBias, 0f, 0f);

                    for (int i = 0; i < count; i++)
                    {
                        Rect tileViewport = sys.TileViewport[i];

                        cmd.SetRenderTarget(_shadowAtlasRT);
                        cmd.SetViewport(tileViewport);
                        cmd.EnableScissorRect(tileViewport);

                        Matrix4x4 lightView = sys.ViewMatrices[i];
                        Matrix4x4 lightProj = sys.ProjMatrices[i]; // 标准 [-1, 1] 矩阵

                        // 直接交给 Unity 处理硬件适配 (不要手动 GL.GetGPU...)
                        cmd.SetViewProjectionMatrices(lightView, lightProj);
                        
                        cmd.SetGlobalVector(_idShadowBias, shadowBias);
                        
                        cmd.SetInvertCulling(enableBackfaceShadowMapping);

                        // Draw
                        var group = sys.GetActiveGroup(i);
                        if (group != null && group.renderers != null)
                        {
                            for (int rIdx = 0; rIdx < group.renderers.Count; rIdx++)
                            {
                                Renderer activeRenderer = group.renderers[rIdx];
                                if (activeRenderer == null || !activeRenderer.gameObject.activeInHierarchy || !activeRenderer.enabled)
                                    continue;

                                Material[] mats = activeRenderer.sharedMaterials;
                                if (mats == null || mats.Length == 0) continue;

                                int safeSubMeshCount = GetSafeSubMeshCount(activeRenderer);
                                int drawCount = Mathf.Min(mats.Length, safeSubMeshCount);

                                for (int j = 0; j < drawCount; j++)
                                {
                                    Material mat = mats[j];
                                    if (mat == null) continue;

                                    int passIndex = mat.FindPass("ShadowCaster");
                                    if (passIndex != -1)
                                        cmd.DrawRenderer(activeRenderer, mat, j, passIndex);
                                }
                            }
                        }

                        cmd.DisableScissorRect();
                    }
                    
                    //防止剔除反转
                    cmd.SetInvertCulling(false);
                }

                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                
                //恢复原相机渲染状态
                context.SetupCameraProperties(renderingData.cameraData.camera);
            }
            finally
            {
                CommandBufferPool.Release(cmd);
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

        public void OnDispose()
        {
            _shadowAtlasRT?.Release();
        }
    }

    public Settings settings = new Settings();
    private CustomRenderPass _pass;

    public override void Create()
    {
        _pass = new CustomRenderPass(settings)
        {
            renderPassEvent = settings.renderPassEvent
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        var sys = PerObjectShadowSystem.Instance;
        if (sys == null) return;
        sys.ApplySettings(settings); // 将配置传给 System (包括自动计算列数)

        if (renderingData.cameraData.renderType == CameraRenderType.Overlay) return;
        if (sys.ActiveCount > 0) renderer.EnqueuePass(_pass);
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        _pass?.OnDispose();
    }
}