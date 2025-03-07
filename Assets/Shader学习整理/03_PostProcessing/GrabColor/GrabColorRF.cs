using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class GrabColorRF : ScriptableRendererFeature 
{
    GrabColorPass m_ScriptablePass;
    public RenderPassEvent m_RenderEvent = RenderPassEvent.AfterRenderingTransparents;
    public Shader shader;
    public override void Create() 
    {
        m_ScriptablePass = new GrabColorPass();
        m_ScriptablePass.renderPassEvent = m_RenderEvent;
        
        if (shader)
        {
            m_ScriptablePass.material = CoreUtils.CreateEngineMaterial(shader);
        }
        
    }
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData) 
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }
    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        m_ScriptablePass.Setup(renderer.cameraColorTargetHandle,shader);
    }
    protected override void Dispose(bool disposing) 
    {
        base.Dispose(disposing);
        m_ScriptablePass.OnDispose();
    }
}


public class GrabColorPass : ScriptableRenderPass 
{
    ProfilingSampler m_Sampler = new("GrabColorPass");
    public Material material;
    RTHandle _cameraColor;
    RTHandle _GrabTex;

    public void GetTempRT(ref RTHandle temp, in RenderingData data)
    {
        RenderTextureDescriptor desc = data.cameraData.cameraTargetDescriptor;
        desc.depthBufferBits = 0; //这步很重要！！！
        RenderingUtils.ReAllocateIfNeeded(ref temp, desc);//使用该函数申请一张与相机大小一致的TempRT;
    }
    
    public void Setup(RTHandle cameraColor,Shader shader) 
    {
        _cameraColor = cameraColor;
    }
    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData) 
    {
        RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
        desc.graphicsFormat = GraphicsFormat.B8G8R8A8_UNorm;
        desc.depthBufferBits = 0;//这步很重要,不然无法blit颜色
        RenderingUtils.ReAllocateIfNeeded(ref _GrabTex, desc);
        cmd.SetGlobalTexture("_GrabColorTex",_GrabTex.nameID);
    }
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) 
    {
        CommandBuffer cmd = CommandBufferPool.Get("GrabColorPass");
        using (new ProfilingScope(cmd, m_Sampler)) 
        {
            if (material)
            {
                Blitter.BlitCameraTexture(cmd,_cameraColor,_GrabTex,material,0);
            }
            else
            {
                Blitter.BlitCameraTexture(cmd,_cameraColor,_GrabTex);
            }
            
        }
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
        cmd.Dispose();
    }
    public override void OnCameraCleanup(CommandBuffer cmd) 
    {
        
    }

    public void OnDispose() 
    {
        CoreUtils.Destroy(material);
        _GrabTex?.Release();
    }
} 