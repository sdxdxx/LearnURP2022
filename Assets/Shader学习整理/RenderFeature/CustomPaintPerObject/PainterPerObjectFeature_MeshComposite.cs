// PainterPerObjectFeature_MeshComposite.cs
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

public class PainterPerObjectFeature_MeshComposite : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        [Tooltip("建议在透明之后、后处理之前")]
        public RenderPassEvent Event = RenderPassEvent.BeforeRenderingPostProcessing;

        [Tooltip("仅处理这些 Layer")]
        public LayerMask layerMask = -1;

        [Header("Materials")]
        [Tooltip("占位“处理”材质：Pass0=Copy（A→B）。自定义单独物体滤镜。")]
        public Material processCopyMaterial;

        [Tooltip("网格合成材质：把 _SourceTex 通过网格贴回相机颜色")]
        public Material meshCompositeMaterial;

        [Header("Selection (no component needed)")]
        [Tooltip("参与标记用的 Shader/材质 Tag 名")]
        public string painterTag = "Painter";

        [Tooltip("同距离次序用的材质属性（可选），留空则仅按距离")]
        public string priorityProperty = "_PainterPriority";
        
        [Tooltip("LightMode")]
        public List<string> shaderTagsList = new List<string>();

        [Header("Advanced")]
        [Tooltip("是否在离屏阶段同时绑定深度 RT（如果材质需要深度测试/自遮挡则开启）")]
        public bool enableOffscreenDepth = false;
    }

    class CustomRenderPass : ScriptableRenderPass
    {
        readonly Settings settings;
        private List<string> shaderTagsList = new List<string>();
        private const string ProfilerTag = "PainterPerObjectPass";
        readonly ProfilingSampler m_ProfilingSampler = new ProfilingSampler(ProfilerTag);

        RTHandle tempRTHandleA;          // 单个物体的离屏颜色
        RTHandle tempRTHandleB;          // “处理”后的颜色（此处为拷贝，占位）
        RTHandle tempDepthRTHandle;      //（可选）离屏深度

        readonly List<Renderer> allRenderers = new List<Renderer>();
        readonly List<(Renderer renderer, Material tagMat, float d2, float prio)> picked = new();

        int priorityPropId = -1;

        public CustomRenderPass(Settings s)
        {
            settings = s;
            renderPassEvent = s.Event;
            
            if (settings.shaderTagsList != null && settings.shaderTagsList.Count > 0)
            {
                for (int i = 0; i < settings.shaderTagsList.Count; i++)
                {
                    shaderTagsList.Add(new string(settings.shaderTagsList[i]));
                }
            }
            else
            {
                shaderTagsList.Add(new string("SRPDefaultUnlit"));
                shaderTagsList.Add(new string("UniversalForward"));
                shaderTagsList.Add(new string("UniversalForwardOnly"));
            }
            
            if (!string.IsNullOrEmpty(s.priorityProperty))
                priorityPropId = Shader.PropertyToID(s.priorityProperty);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData data)
        {
            //获取所需的临时RT
            var desc = data.cameraData.cameraTargetDescriptor;
            desc.msaaSamples = 1;       // 中间 RT 不用 MSAA
            desc.depthBufferBits = 0;   // 颜色 RT 无深度
            RenderingUtils.ReAllocateIfNeeded(ref tempRTHandleA, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: "_Painter_TempA");
            RenderingUtils.ReAllocateIfNeeded(ref tempRTHandleB, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: "_Painter_TempB");

            //根据情况判断是否需要DepthRT
            if (settings.enableOffscreenDepth)
            {
                var depthDesc = data.cameraData.cameraTargetDescriptor;
                depthDesc.colorFormat = RenderTextureFormat.Depth;
                depthDesc.depthBufferBits = 32;
                depthDesc.msaaSamples = 1;
                RenderingUtils.ReAllocateIfNeeded(ref tempDepthRTHandle, depthDesc, name: "_Painter_TempDepth");
            }
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (settings.processCopyMaterial == null || settings.meshCompositeMaterial == null)
                return;

            var cam = renderingData.cameraData.camera;
            var cmd = CommandBufferPool.Get(ProfilerTag);

            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                // 1) 收集候选（零挂件：遍历可见 Renderer，挑出材质 Tag 命中的）
                allRenderers.Clear();
                allRenderers.AddRange(Object.FindObjectsOfType<Renderer>());
                picked.Clear();

                foreach (var renderer in allRenderers)
                {
                    if (!renderer || !renderer.enabled) continue;
                    if (!renderer.isVisible) continue;
                    if (((1 << renderer.gameObject.layer) & settings.layerMask) == 0) continue;//如果当前 renderer 所在的层不在 settings.layerMask 里，就跳过本次循环
                    

                    // 判断Render中是否有带 Tag 的材质
                    var mats = renderer.sharedMaterials;
                    Material tagMat = null;
                    for (int i = 0; i < mats.Length; i++)
                    {
                        var m = mats[i];
                        if (!m) continue;
                        // GetTag 读取 SubShader Tag
                        string v = m.GetTag(settings.painterTag, false, "0");
                        if (v == "1") { tagMat = m; break; }
                    }
                    if (tagMat == null) continue;

                    float d2 = (cam.transform.position - renderer.bounds.center).sqrMagnitude;
                    float prio = 0;
                    if (priorityPropId != -1 && tagMat.HasProperty(priorityPropId))
                        prio = tagMat.GetFloat(priorityPropId);

                    picked.Add((renderer, tagMat, d2, prio));
                }

                // 2) 从远到近排序（画家）；同距按 prio 升序
                picked.Sort((a, b) =>
                {
                    int cmp = b.d2.CompareTo(a.d2);  // 远在前
                    if (cmp != 0) return cmp;
                    return a.prio.CompareTo(b.prio); // prio 小者先（更底层）
                });
                //Sort(a,b)是C#自带的列表内容排序函数
                // 比较器接收 a、b 两个元素，返回值含义：
                //     < 0：a 应排在 b 前
                //     = 0：两者顺序视为相同
                //     > 0：a 应排在 b 后
                //CompareTo() 是实现了 IComparable<T> 的类型（如 int/float/double）自带的比较函数

                // 3) 逐对象：离屏 A → 处理到 B（此处为 Copy） → 网格合成
                var cameraColor = renderingData.cameraData.renderer.cameraColorTargetHandle;
                var cameraDepth = renderingData.cameraData.renderer.cameraDepthTargetHandle;

                foreach (var it in picked)
                {
                    var renderer = it.renderer;
                    if (!renderer) continue;

                    // 3.1 离屏：把该物体画到 tempRTHandleA
                    if (settings.enableOffscreenDepth && tempDepthRTHandle != null)
                    {
                        CoreUtils.SetRenderTarget(cmd, tempRTHandleA, tempDepthRTHandle);
                        CoreUtils.ClearRenderTarget(cmd, ClearFlag.All, Color.clear);
                    }
                    else
                    {
                        CoreUtils.SetRenderTarget(cmd, tempRTHandleA);
                        CoreUtils.ClearRenderTarget(cmd, ClearFlag.Color, Color.clear);
                    }

                    // 逐 submesh 保持原材质绘制
                    var mats = renderer.sharedMaterials;
                    for (int index = 0; index < mats.Length; index++)
                    {
                        var mat = mats[index];
                        if (mat)
                        {
                            foreach (var shaderTag in shaderTagsList)
                            {
                                int pass = mat.FindPass(shaderTag) ;
                                if (pass < 0) pass = 0;
                                cmd.DrawRenderer(renderer, mat, index, pass);//绘制所有Pass
                            }
                        }
                            
                    }

                    // 3.2 占位“处理”：A → B（后续可替换为单物体滤镜）
                    Blitter.BlitCameraTexture(cmd, tempRTHandleA, tempRTHandleB, settings.processCopyMaterial, 0);

                    // 3.3 网格合成：仅在该网格覆盖区域把 tempRTHandleB 贴回相机颜色
                    cmd.SetGlobalTexture("_SourceTex", tempRTHandleB.nameID);
                    CoreUtils.SetRenderTarget(cmd, cameraColor,cameraDepth);
                    cmd.DrawRenderer(renderer, settings.meshCompositeMaterial, 0, -1);//绘制所有Pass
                }
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            /* RTHandle 由 ReAllocateIfNeeded 管理 */ 
            
        }
        
        public void OnDispose() 
        {
            tempRTHandleA?.Release();//如果tempRTHandle没被释放的话，会被释放
            tempRTHandleB?.Release();//如果tempRTHandle没被释放的话，会被释放
            tempDepthRTHandle?.Release();//如果tempRTHandle没被释放的话，会被释放
        }
        
    }

    public Settings settings = new Settings();
    CustomRenderPass m_ScriptablePass;

    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass(settings);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }
    
    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        m_ScriptablePass.OnDispose();
    }
}
