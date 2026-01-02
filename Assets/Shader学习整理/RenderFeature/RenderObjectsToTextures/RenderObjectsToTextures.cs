using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class RenderObjectsToTextures : ScriptableRendererFeature
{
    // 单个渲染目标的配置结构
    [System.Serializable]
    public class TargetSetting
    {
        [Tooltip("Shader中的LightMode Tag")]
        public string lightModeTag = "RenderMask";

        [Tooltip("生成的贴图的全局名称")]
        public string textureName = "_MaskTex";

        [Tooltip("贴图格式: Mask通常用R8, 彩色内容用Default(RGBA)")]
        public RenderTextureFormat textureFormat = RenderTextureFormat.R8;
    }

    [System.Serializable]
    public class Settings
    {
        // 全局设置
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        
        [Header("Filters")]
        public RenderQueueType renderQueueType = RenderQueueType.Opaque;
        public LayerMask layerMask = -1; // Everything

        [Header("Global Settings")]
        [Range(1, 4)] public int downSample = 1; // 降采样

        [Header("Targets")]
        public List<TargetSetting> renderTargets = new List<TargetSetting>();
    }

    // Pass 实现
    class RenderObjectsToTexturesPass : ScriptableRenderPass
    {
        private Settings settings;
        private FilteringSettings m_FilteringSettings;
        private RenderStateBlock m_RenderStateBlock;
        
        // 使用字典管理 Color RTHandles
        private Dictionary<string, RTHandle> m_Handles = new Dictionary<string, RTHandle>();
        // 公用的 Depth RTHandle
        private RTHandle m_DepthHandle;
        
        private string m_ProfilerTag;
        private ProfilingSampler m_ProfilingSampler;

        public RenderObjectsToTexturesPass(string featureName, Settings settings)
        {
            // 初始化 Tag 和 Sampler
            m_ProfilerTag = featureName;
            m_ProfilingSampler = new ProfilingSampler(featureName);
            
            this.settings = settings;
            this.renderPassEvent = settings.renderPassEvent;

            RenderQueueRange queueRange = (settings.renderQueueType == RenderQueueType.Transparent)
                ? RenderQueueRange.transparent
                : RenderQueueRange.opaque;
            
            m_FilteringSettings = new FilteringSettings(queueRange, settings.layerMask);
            m_RenderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (settings.renderTargets == null || settings.renderTargets.Count == 0) return;

            CommandBuffer cmd = CommandBufferPool.Get(m_ProfilerTag);
            
            // 1. 准备基础描述信息
            RenderTextureDescriptor baseDesc = renderingData.cameraData.cameraTargetDescriptor;
            baseDesc.msaaSamples = 1;
            baseDesc.width /= settings.downSample;
            baseDesc.height /= settings.downSample;

            // 2. 申请公用的深度 RT
            RenderTextureDescriptor depthDesc = baseDesc;
            depthDesc.colorFormat = RenderTextureFormat.Depth; 
            depthDesc.depthBufferBits = 32; // 确保有足够的精度
            
            // 确保分配深度纹理
            RenderingUtils.ReAllocateIfNeeded(ref m_DepthHandle, depthDesc, name: "_SharedDepthTex");

            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                foreach (var target in settings.renderTargets)
                {
                    if (string.IsNullOrEmpty(target.lightModeTag) || string.IsNullOrEmpty(target.textureName)) continue;

                    // 3. 准备当前 Color RT 的描述
                    RenderTextureDescriptor colorDesc = baseDesc;
                    colorDesc.colorFormat = target.textureFormat;
                    colorDesc.depthBufferBits = 0; // Color RT 本身不需要携带深度Buffer，因为我们有独立的 m_DepthHandle

                    // 4. 设置绘制规则
                    DrawingSettings drawingSettings = CreateDrawingSettings(
                        new ShaderTagId(target.lightModeTag), 
                        ref renderingData, 
                        renderingData.cameraData.defaultOpaqueSortFlags 
                    );

                    // 5. 获取或创建 Color RTHandle
                    if (!m_Handles.ContainsKey(target.textureName) || m_Handles[target.textureName] == null)
                    {
                        m_Handles[target.textureName] = null;
                    }

                    var colorHandle = m_Handles[target.textureName];
                    RenderingUtils.ReAllocateIfNeeded(ref colorHandle, colorDesc, name: target.textureName);
                    m_Handles[target.textureName] = colorHandle;

                    // 6. 设置 RenderTarget (Color + Depth) 并清除
                    // 关键点：传入 m_DepthHandle 作为深度附件
                    // ClearFlag.All：同时清除 颜色(变黑/透) 和 深度(重置Z值)，确保当前Pass的渲染是干净的
                    CoreUtils.SetRenderTarget(cmd, m_Handles[target.textureName], m_DepthHandle, ClearFlag.All, Color.clear);
                    
                    // 执行一下 SetRenderTarget 命令，确保状态切换
                    context.ExecuteCommandBuffer(cmd); 
                    cmd.Clear();

                    // 7. 绘制物体
                    // 因为绑定了 Depth Buffer，这里的 DrawRenderers 会正确执行 ZTest 和 ZWrite
                    context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref m_FilteringSettings, ref m_RenderStateBlock);
                    
                    // 8. 设置全局纹理
                    cmd.SetGlobalTexture(target.textureName, m_Handles[target.textureName]);
                }
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public void OnDispose()
        {
            // 释放所有 Color RT
            foreach (var kvp in m_Handles)
            {
                kvp.Value?.Release();
            }
            m_Handles.Clear();

            // 释放公用的 Depth RT
            m_DepthHandle?.Release();
        }
    }

    //-------------------------------------------------------------------------------------------------------
    
    public Settings settings = new Settings();
    private RenderObjectsToTexturesPass m_ScriptablePass;

    public override void Create()
    {
        m_ScriptablePass = new RenderObjectsToTexturesPass(this.name,settings);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (renderingData.cameraData.cameraType == CameraType.Game || renderingData.cameraData.cameraType == CameraType.SceneView)
        {
            renderer.EnqueuePass(m_ScriptablePass);
        }
    }

    protected override void Dispose(bool disposing)
    {
        m_ScriptablePass?.OnDispose();
    }
}