using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class LoopRenderPassFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        public RenderQueueType renderQueueType = RenderQueueType.Opaque;
        public LayerMask layerMask = -1;

        // 默认为空
        public List<string> lightModeTags = new List<string>();

        [Range(1, 300)]
        public int loopTimes = 1;
    }
    
    class LoopRenderPass : ScriptableRenderPass
    {
        string m_ProfilerTag;
        LoopRenderPassFeature.Settings m_Settings;
        List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>();
        FilteringSettings m_FilteringSettings;

        // 缓存 Shader 属性 ID，提高性能
        static readonly int LoopIndexId = Shader.PropertyToID("_LoopIndex");
        static readonly int LoopTimesId = Shader.PropertyToID("_LoopTimes");

        public LoopRenderPass(string profilerTag, LoopRenderPassFeature.Settings settings)
        {
            m_ProfilerTag = profilerTag;
            m_Settings = settings;

            // 只添加用户指定的 Tag
            if (m_Settings.lightModeTags != null && m_Settings.lightModeTags.Count > 0)
            {
                foreach (var tag in m_Settings.lightModeTags)
                {
                    m_ShaderTagIdList.Add(new ShaderTagId(tag));
                }
            }

            RenderQueueRange queue = (settings.renderQueueType == RenderQueueType.Transparent)
                ? RenderQueueRange.transparent
                : RenderQueueRange.opaque;

            m_FilteringSettings = new FilteringSettings(queue, settings.layerMask);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (m_ShaderTagIdList.Count == 0)
                return;

            CommandBuffer cmd = CommandBufferPool.Get(m_ProfilerTag);

            // 1. 设置总循环次数 (这是一个全局变量，这一帧里对于这个Pass是固定的)
            cmd.SetGlobalFloat(LoopTimesId, m_Settings.loopTimes);
            
            // 立即执行并清理，确保 LoopTimes 写入 GPU
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            // 开启 Frame Debugger 采样范围
            // 注意：因为我们在循环中多次 Execute/Clear cmd，ProfilingScope 需要包裹住整个逻辑
            // 但为了让 Frame Debugger 结构清晰，我们手动 Begin/End Sample
            cmd.BeginSample(m_ProfilerTag);
            context.ExecuteCommandBuffer(cmd); // 执行 BeginSample
            cmd.Clear();

            for (int i = 0; i < m_Settings.loopTimes; i++)
            {
                // 2. 设置当前 Index (0, 1, 2...)
                cmd.SetGlobalFloat(LoopIndexId, i);
                
                // 【关键步骤】
                // 必须立即执行 CommandBuffer，让 GPU 也就是 Shader 拿到最新的 _LoopIndex
                // 如果不在这里 Execute，所有的 SetGlobalFloat 会堆积到最后，导致所有 Pass 用的都是最后一个 i
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear(); // 清空 Buffer 准备下一个命令

                // 3. 绘制
                var drawingSettings = CreateDrawingSettings(m_ShaderTagIdList, ref renderingData, SortingCriteria.CommonOpaque);
                context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref m_FilteringSettings);
            }

            // 结束采样
            cmd.EndSample(m_ProfilerTag);
            context.ExecuteCommandBuffer(cmd);
            
            CommandBufferPool.Release(cmd);
        }
    }

    public Settings settings = new Settings();
    LoopRenderPass m_ScriptablePass;

    public override void Create()
    {
        m_ScriptablePass = new LoopRenderPass(this.name, settings);
        m_ScriptablePass.renderPassEvent = settings.renderPassEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }
}