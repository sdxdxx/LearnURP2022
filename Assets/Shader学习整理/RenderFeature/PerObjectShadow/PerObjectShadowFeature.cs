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
        [Range(1, 4)] public int shadowAtlasTileColumns = 4;
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

        private RTHandle _cameraColor;
        private RTHandle _cameraDepth;
        private RTHandle _shadowAtlasRT;

        private readonly int _idAtlas;
        private readonly int _idMatArr;
        private readonly int _idUVArr;
        private readonly int _idCount;
        private readonly int _idShadowBiasGen;

        // IDs for ShadowCasterPass context (built-in globals)
        private static readonly int _idWorldSpaceCameraPos = Shader.PropertyToID("_WorldSpaceCameraPos");
        private static readonly int _idLightDirection = Shader.PropertyToID("_LightDirection");
        private static readonly int _idShadowBias = Shader.PropertyToID("_ShadowBias");
        private static readonly int _idUnityLightShadowBias = Shader.PropertyToID("unity_LightShadowBias");

        public CustomRenderPass(Settings settings)
        {
            _settings = settings;
            _idAtlas = Shader.PropertyToID(_settings.atlasTexName);
            _idMatArr = Shader.PropertyToID(_settings.matrixArrayName);
            _idUVArr = Shader.PropertyToID(_settings.uvClampArrayName);
            _idCount = Shader.PropertyToID(_settings.countName);
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
            Vector3 camPosWS = renderingData.cameraData.worldSpaceCameraPos;

            CommandBuffer cmd = CommandBufferPool.Get(ProfilerTag);

            try
            {
                using (new ProfilingScope(cmd, _profilingSampler))
                {
                    // Clear atlas depth
                    cmd.SetRenderTarget(_shadowAtlasRT);
                    cmd.ClearRenderTarget(true, false, Color.clear);

                    // Globals for sampling in your forward shader
                    cmd.SetGlobalTexture(_idAtlas, _shadowAtlasRT);
                    cmd.SetGlobalInt(_idCount, count);
                    cmd.SetGlobalMatrixArray(_idMatArr, sys.WorldToShadowAtlasMatrices);
                    cmd.SetGlobalVectorArray(_idUVArr, sys.UVClamp);

                    // Your per-object sampling bias (for receiver-side compare)
                    cmd.SetGlobalVector(_idShadowBiasGen, new Vector4(_settings.depthBias, _settings.normalBias, 0, 0));

                    // Prepare light direction for ShadowCasterPass context:
                    // ShadowCaster expects "_LightDirection" = direction from surface -> light
                    // while directional light forward is typically light -> surface, so we negate it.
                    Vector3 surfaceToLightDirWS = Vector3.back;
                    if (sys.mainLight != null)
                        surfaceToLightDirWS = (-sys.mainLight.transform.forward).normalized;

                    // ShadowCasterPass uses _ShadowBias and sometimes unity_LightShadowBias
                    Vector4 shadowBias = new Vector4(_settings.depthBias, _settings.normalBias, 0f, 0f);

                    for (int i = 0; i < count; i++)
                    {
                        Rect tileViewport = sys.TileViewport[i];

                        cmd.SetRenderTarget(_shadowAtlasRT);
                        cmd.SetViewport(tileViewport);
                        cmd.EnableScissorRect(tileViewport);

                        Matrix4x4 lightView = sys.ViewMatrices[i];
                        Matrix4x4 lightProj = sys.ProjMatrices[i];
                        Matrix4x4 gpuProj = GL.GetGPUProjectionMatrix(lightProj, true);

                        // 1) Switch VP to the per-object light camera
                        cmd.SetViewProjectionMatrices(lightView, gpuProj);

                        // 2) Provide correct ShadowCaster context constants (light direction / bias / camera pos)
                        cmd.SetGlobalVector(_idLightDirection, new Vector4(surfaceToLightDirWS.x, surfaceToLightDirWS.y, surfaceToLightDirWS.z, 0f));
                        cmd.SetGlobalVector(_idShadowBias, shadowBias);
                        cmd.SetGlobalVector(_idUnityLightShadowBias, shadowBias);

                        // Ensure _WorldSpaceCameraPos matches the light camera position for this pass
                        Vector3 lightPosWS = lightView.inverse.MultiplyPoint3x4(Vector3.zero);
                        cmd.SetGlobalVector(_idWorldSpaceCameraPos, lightPosWS);

                        // 3) If GPU projection flips Y, winding can be inverted. Match culling for consistent draw.
                        bool invertCulling = gpuProj.m11 < 0f;
                        cmd.SetInvertCulling(invertCulling);

                        // Draw: each selected entry is a group of renderers (treated as ONE model, share ONE tile)
                        var group = sys.GetActiveGroup(i);
                        if (group != null && group.renderers != null)
                        {
                            for (int rIdx = 0; rIdx < group.renderers.Count; rIdx++)
                            {
                                Renderer activeRenderer = group.renderers[rIdx];
                                if (activeRenderer == null)
                                    continue;
                                if (!activeRenderer.gameObject.activeInHierarchy || !activeRenderer.enabled)
                                    continue;

                                Material[] mats = activeRenderer.sharedMaterials;
                                if (mats == null || mats.Length == 0)
                                    continue;

                                int safeSubMeshCount = GetSafeSubMeshCount(activeRenderer);
                                int drawCount = Mathf.Min(mats.Length, safeSubMeshCount);

                                for (int j = 0; j < drawCount; j++)
                                {
                                    Material mat = mats[j];
                                    if (mat == null)
                                        continue;

                                    int passIndex = mat.FindPass("ShadowCaster");
                                    if (passIndex != -1)
                                        cmd.DrawRenderer(activeRenderer, mat, j, passIndex);
                                }
                            }
                        }

                        // Restore state for next tile
                        cmd.SetInvertCulling(false);
                        cmd.DisableScissorRect();
                    }

                    // Restore camera target / viewport / VP
                    cmd.SetRenderTarget(_cameraColor, _cameraDepth);
                    cmd.SetViewport(camViewport);
                    cmd.SetViewProjectionMatrices(camView, camProj);

                    // Restore camera position global (we changed it during per-tile rendering)
                    cmd.SetGlobalVector(_idWorldSpaceCameraPos, camPosWS);
                }

                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                // Keep URP camera state consistent
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

    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        _pass.Setup(renderer.cameraColorTargetHandle, renderer.cameraDepthTargetHandle);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        var sys = PerObjectShadowSystem.Instance;
        if (sys == null) return;

        sys.ApplySettings(settings);

        if (renderingData.cameraData.renderType == CameraRenderType.Overlay)
            return;

        if (sys.ActiveCount > 0)
            renderer.EnqueuePass(_pass);
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        _pass?.OnDispose();
    }
}
