using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class SimpleMainLightShadowMapFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;

        [Header("Shadowmap")]
        public int shadowMapResolution = 1024;
        public int depthBits = 16;
        public FilterMode filterMode = FilterMode.Bilinear;
        public LayerMask layerMask = -1;

        [Header("Only render objects with this LightMode pass")]
        public string shadowCasterLightModeTag = "CustomShadowCaster";

        [Header("Global shader names")]
        public string shadowmapTexName = "_SimpleMainLightShadowmap";
        public string worldToShadowName = "_SimpleMainLightWorldToShadow";
        public string shadowmapSizeName = "_SimpleMainLightShadowmapSize";
    }

    class ShadowPass : ScriptableRenderPass
    {
        const string ProfilerTag = "SimpleMainLightShadowmap";
        readonly ProfilingSampler sampler = new ProfilingSampler(ProfilerTag);

        Settings settings;

        RTHandle shadowRT;
        ShaderTagId shaderTagId;

        int shadowTexID;
        int worldToShadowID;
        int shadowSizeID;

        public ShadowPass(Settings settings) => Setup(settings);

        public void Setup(Settings settings)
        {
            this.settings = settings;
            renderPassEvent = this.settings.renderPassEvent;

            shaderTagId = new ShaderTagId(this.settings.shadowCasterLightModeTag);

            shadowTexID = Shader.PropertyToID(this.settings.shadowmapTexName);
            worldToShadowID = Shader.PropertyToID(this.settings.worldToShadowName);
            shadowSizeID = Shader.PropertyToID(this.settings.shadowmapSizeName);
        }

        public void Dispose()
        {
            shadowRT?.Release();
            shadowRT = null;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            int res = Mathf.Max(1, settings.shadowMapResolution);
            int depthBits = (settings.depthBits <= 0) ? 16 : settings.depthBits;

            var desc = new RenderTextureDescriptor(res, res, RenderTextureFormat.Shadowmap, depthBits)
            {
                msaaSamples = 1,
                sRGB = false,
                useMipMap = false,
                autoGenerateMips = false,
                enableRandomWrite = false
            };

            RenderingUtils.ReAllocateIfNeeded(
                ref shadowRT,
                desc,
                settings.filterMode,
                TextureWrapMode.Clamp,
                name: settings.shadowmapTexName
            );

            ConfigureTarget(shadowRT);
            ConfigureClear(ClearFlag.None, Color.black); // 清理放到 Execute 手动做
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            int mainLightIndex = renderingData.lightData.mainLightIndex;
            if (mainLightIndex < 0 || mainLightIndex >= renderingData.lightData.visibleLights.Length)
                return;

            var vl = renderingData.lightData.visibleLights[mainLightIndex];
            if (vl.lightType != LightType.Directional || vl.light == null)
                return;

            Matrix4x4 viewMatrix, projMatrix;
            ShadowSplitData splitData;

            bool ok = renderingData.cullResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(
                mainLightIndex,
                0,
                1,
                Vector3.one,
                Mathf.Max(1, settings.shadowMapResolution),
                vl.light.shadowNearPlane,
                out viewMatrix,
                out projMatrix,
                out splitData
            );
            if (!ok) return;

            // 注意：这里我们用于“实际渲染”的矩阵用 GPUProj，确保和 shader 端 positionCS 一致
            Matrix4x4 gpuProj = GL.GetGPUProjectionMatrix(projMatrix, true);

            // world -> shadow uv（0..1）
            Matrix4x4 scaleBias = Matrix4x4.identity;
            scaleBias.SetRow(0, new Vector4(0.5f, 0f,   0f, 0.5f));
            scaleBias.SetRow(1, new Vector4(0f,   0.5f, 0f, 0.5f));
            scaleBias.SetRow(2, new Vector4(0f,   0f,   1f, 0f));
            scaleBias.SetRow(3, new Vector4(0f,   0f,   0f, 1f));
            Matrix4x4 worldToShadow = scaleBias * (gpuProj * viewMatrix);

            bool reversedZ = SystemInfo.usesReversedZBuffer;
            float clearDepth = reversedZ ? 0f : 1f;
            CompareFunction depthCompare = reversedZ ? CompareFunction.GreaterEqual : CompareFunction.LessEqual;

            int res = Mathf.Max(1, settings.shadowMapResolution);

            var cmd = CommandBufferPool.Get(ProfilerTag);
            using (new ProfilingScope(cmd, sampler))
            {
                // 1) 绑定 RT + 正确清深度
                cmd.SetRenderTarget(shadowRT);
                // Unity 2022 的 ClearRenderTarget 有带 depth 的重载；如果你项目报签名不匹配，告诉我报错我给你换兼容写法
                cmd.ClearRenderTarget(true, false, Color.black, clearDepth);
                cmd.SetViewport(new Rect(0, 0, res, res));

                // 2) 设置 VP（用于 CustomShadowCaster pass 写深度）
                cmd.SetViewProjectionMatrices(viewMatrix, gpuProj);

                // 3) 设置全局（用于 ForwardLit 采样）
                cmd.SetGlobalTexture(shadowTexID, shadowRT);
                cmd.SetGlobalMatrix(worldToShadowID, worldToShadow);
                cmd.SetGlobalVector(shadowSizeID, new Vector4(1.0f / res, 1.0f / res, res, res));

                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                // 4) 绘制：强制正确深度比较（关键！）
                var sorting = new SortingSettings(renderingData.cameraData.camera) { criteria = SortingCriteria.None };
                var drawing = new DrawingSettings(shaderTagId, sorting)
                {
                    perObjectData = PerObjectData.None,
                    enableDynamicBatching = false,
                    enableInstancing = true
                };
                var filtering = new FilteringSettings(RenderQueueRange.opaque, settings.layerMask);

                var stateBlock = new RenderStateBlock(RenderStateMask.Depth)
                {
                    depthState = new DepthState(true, depthCompare)
                };

                context.DrawRenderers(renderingData.cullResults, ref drawing, ref filtering, ref stateBlock);

                // 5) 恢复相机状态，避免影响后续 Pass
                context.SetupCameraProperties(renderingData.cameraData.camera);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }

    
    public Settings settings = new Settings();
    ShadowPass pass;
    
    public override void Create()
    {
        pass = new ShadowPass(settings);
    }

    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        pass.Setup(settings);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(pass);
    }

    protected override void Dispose(bool disposing)
    {
        pass?.Dispose();
        base.Dispose(disposing);
    }
}
