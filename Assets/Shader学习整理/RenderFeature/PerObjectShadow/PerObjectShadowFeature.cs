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
        public LayerMask hideLayerMask;
        public float maxDistance = 35f;
        [Range(1, 10)] public int maxTargets = 10;

        [Header("Atlas Settings")]
        public int shadowAtlasSize = 2048;
        [Range(1,4)]public int shadowAtlasTileColumns = 4;
        public int shadowAtlasTileBorderPixels = 2;

        [Header("Light Camera Settings")]
        // 【关键修复 1】大幅减小向后延伸的距离。
        // 对于单体角色，10米-20米通常足够。过大会浪费 Z 轴精度。
        public float lightCameraBackDistance = 10f; 

        // 【关键修复 2】核心问题所在。
        // 原来的 5.0f 会导致 Near/Far 平面距离拉得太开，稀释了 ShadowMap 精度。
        // 设为 0.5f 或更小，紧贴物体包围盒，能最大化利用 16bit 深度精度。
        public float depthPadding = 0.5f; 

        public float xyPadding = 0.2f;

        [Header("Bias Settings")]
        // 既然精度提高了，Bias 可以保持很小
        [Range(0.0f, 0.2f)] public float depthBias = 0.005f; 
        [Range(0.0f, 1.0f)] public float normalBias = 0.05f; 
    }

    private class CustomRenderPass : ScriptableRenderPass
    {
        private const string ProfilerTag = "PerObjectShadowPass";
        private readonly ProfilingSampler _profilingSampler = new(ProfilerTag);

        private readonly Settings _settings;

        private RTHandle _cameraColor;
        private RTHandle _cameraDepth;
        private RTHandle _shadowAtlasRT;

        private readonly int _idAtlas;
        private readonly int _idMatArr;
        private readonly int _idUVArr;
        private readonly int _idCount;
        private readonly int _idShadowBiasGen;

        public CustomRenderPass(Settings settings)
        {
            _settings = settings;
            _idAtlas         = Shader.PropertyToID(_settings.atlasTexName);
            _idMatArr        = Shader.PropertyToID(_settings.matrixArrayName);
            _idUVArr         = Shader.PropertyToID(_settings.uvClampArrayName);
            _idCount         = Shader.PropertyToID(_settings.countName);
            _idShadowBiasGen = Shader.PropertyToID("_PerObjectShadowBiasGen");
        }

        public void Setup(RTHandle cameraColor, RTHandle cameraDepth)
        {
            _cameraColor = cameraColor;
            _cameraDepth = cameraDepth;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
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
            Rect camViewport = GetCameraViewportRect(ref renderingData);
            Matrix4x4 camView = renderingData.cameraData.GetViewMatrix();
            Matrix4x4 camProj = renderingData.cameraData.GetGPUProjectionMatrix();

            CommandBuffer cmd = CommandBufferPool.Get(ProfilerTag);

            try
            {
                using (new ProfilingScope(cmd, _profilingSampler))
                {
                    cmd.SetRenderTarget(_shadowAtlasRT);
                    cmd.ClearRenderTarget(true, false, Color.clear);

                    cmd.SetGlobalTexture(_idAtlas, _shadowAtlasRT);
                    cmd.SetGlobalInt(_idCount, count);
                    cmd.SetGlobalMatrixArray(_idMatArr, sys.WorldToShadowAtlasMatrices);
                    cmd.SetGlobalVectorArray(_idUVArr, sys.UVClamp);
                    
                    // 传递 Bias 给 Shader 采样用
                    cmd.SetGlobalVector(_idShadowBiasGen, new Vector4(_settings.depthBias, _settings.normalBias, 0, 0));
                    
                    // 既然问题是由于 Near/Far 平面过大导致的精度不足
                    // 只要 Padding 调小了，这里不需要额外的 Slope Bias 也能得到很好的效果
                    // 保持最纯净的绘制
                    
                    for (int i = 0; i < count; i++)
                    {
                        Rect tileViewport = sys.TileViewport[i];

                        cmd.SetRenderTarget(_shadowAtlasRT);
                        cmd.SetViewport(tileViewport);
                        cmd.EnableScissorRect(tileViewport);

                        Matrix4x4 lightView = sys.ViewMatrices[i];
                        Matrix4x4 lightProj = sys.ProjMatrices[i];
                        Matrix4x4 gpuProj = GL.GetGPUProjectionMatrix(lightProj, true);
                        cmd.SetViewProjectionMatrices(lightView, gpuProj);

                        Renderer activeRenderer = sys.GetActiveRenderer(i);
                        if (activeRenderer != null && activeRenderer.gameObject.activeInHierarchy && activeRenderer.enabled)
                        {
                            int subMeshCount = 1;
                            Material sharedMat = activeRenderer.sharedMaterial;

                            if (activeRenderer is MeshRenderer meshRenderer && meshRenderer.sharedMaterials != null)
                            {
                                subMeshCount = meshRenderer.sharedMaterials.Length;
                                sharedMat = meshRenderer.sharedMaterial;
                            }
                            else if (activeRenderer is SkinnedMeshRenderer skinnedMeshRenderer && skinnedMeshRenderer.sharedMaterials != null)
                            {
                                subMeshCount = skinnedMeshRenderer.sharedMaterials.Length;
                                sharedMat = skinnedMeshRenderer.sharedMaterial;
                            }

                            if (sharedMat != null)
                            {
                                int passIndex = sharedMat.FindPass("ShadowCaster");
                                if (passIndex != -1)
                                {
                                    for (int j = 0; j < subMeshCount; j++)
                                        cmd.DrawRenderer(activeRenderer, sharedMat, j, passIndex);
                                }
                            }
                        }
                        cmd.DisableScissorRect();
                    }

                    cmd.SetRenderTarget(_cameraColor, _cameraDepth);
                    cmd.SetViewport(camViewport);
                    cmd.SetViewProjectionMatrices(camView, camProj);
                }

                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                
                context.SetupCameraProperties(renderingData.cameraData.camera);
            }
            finally
            {
                CommandBufferPool.Release(cmd);
            }
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

    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        _pass.Setup(renderer.cameraColorTargetHandle, renderer.cameraDepthTargetHandle);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        var sys = PerObjectShadowSystem.Instance;
        if (sys == null) return;

        sys.ApplySettings(settings);

        if (renderingData.cameraData.renderType == CameraRenderType.Overlay) return;

        if (sys.ActiveCount > 0)
            renderer.EnqueuePass(_pass);
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        _pass?.OnDispose();
    }
}