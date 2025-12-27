using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;

[ExecuteAlways]
public class PerObjectShadowSystem : MonoBehaviour
{
    public static PerObjectShadowSystem Instance { get; private set; }

    [Header("Scene References")]
    public Light mainLight;                       
    public Camera mainCamera;                     

    [Header("Auto Collect")]
    public List<Renderer> candidatesRenderers = new List<Renderer>();
    public List<Transform> candidateRoots = new List<Transform>();
    public bool autoCollectFromRoots = false;
    
    [Header("Debug")]
    public bool debugDraw = false;

    // ==========================================
    // Config (由 Feature 注入)
    // ==========================================
    private LayerMask _hideLayerMask;//把某些 Layer 的 Renderer 从候选中排除
    private float _maxDistance;//距离阈值，超过这个距离的 candidate 不会被选入 per-object shadow
    private int _maxTargets;//最多同时给多少个对象分配 tile 并渲染 shadow

    private int _shadowAtlasSize;//整张 shadow atlas 的分辨率
    private int _shadowAtlasTileColumns;//shadow atlas 横向切几列
    private int _shadowAtlasTileSize; //每个 tile 的像素宽高
    private int _shadowAtlasTileBorderPixels;//tile 边缘保留的像素边框，防止滤波/PCF 跨 tile 采到别人的内容

    private float _lightCameraBackDistance;
    private float _depthPadding;
    private float _xyPadding;

    // Output Data
    public int ActiveCount { get; private set; }//本帧被选中要投影的对象数量
    public readonly Matrix4x4[] ViewMatrices = new Matrix4x4[10];
    public readonly Matrix4x4[] ProjMatrices = new Matrix4x4[10];
    public readonly Matrix4x4[] WorldToShadowAtlasMatrices = new Matrix4x4[10];
    public readonly Vector4[] UVClamp = new Vector4[10];
    public readonly Rect[] TileViewport = new Rect[10];

    private readonly List<Renderer> _selectedRenderers = new();

    private void Awake()
    {
        Instance = this;
    }

    private void OnDestroy()
    {
        if (Instance == this) Instance = null;
    }

    public void ApplySettings(PerObjectShadowFeature.Settings settings)
    {
        _hideLayerMask = settings.hideLayerMask;
        _maxDistance = settings.maxDistance;
        _maxTargets = settings.maxTargets;

        _shadowAtlasSize = settings.shadowAtlasSize;
        _shadowAtlasTileColumns = settings.shadowAtlasTileColumns;
        _shadowAtlasTileBorderPixels = settings.shadowAtlasTileBorderPixels;
        
        if (_shadowAtlasTileColumns > 0)
            _shadowAtlasTileSize = _shadowAtlasSize / _shadowAtlasTileColumns;
        else
            _shadowAtlasTileSize = 512;

        _lightCameraBackDistance = settings.lightCameraBackDistance;
        _depthPadding = settings.depthPadding;
        _xyPadding = settings.xyPadding;
    }

    private void LateUpdate()
    {
        var cam = mainCamera != null ? mainCamera : Camera.main;
        if (cam == null || mainLight == null) return;
        if (mainLight.type != LightType.Directional) return;

        if (autoCollectFromRoots)
            CollectCandidatesFromRoots();

        UpdateSelection(cam);
        UpdateMatricesAndAtlas(cam);

        //Debug
        if (debugDraw)
        {
            DebugDrawLightOrthoRanges();
        }
    }

    private void CollectCandidatesFromRoots()
    {
        candidatesRenderers.Clear();
        for (int i = 0; i < candidateRoots.Count; i++)
        {
            var root = candidateRoots[i];
            if (root == null) 
                continue;
            var childRenderers = root.GetComponentsInChildren<Renderer>(includeInactive: false);
            for (int j = 0; j < childRenderers.Length; j++)
            {
                if (childRenderers[j] != null) 
                    candidatesRenderers.Add(childRenderers[j]);
            }
        }
    }

    private void UpdateSelection(Camera cam)
    {
        _selectedRenderers.Clear();
        // 增加一个极小值防止除0或完全不可见，虽然实际上距离剔除主要靠sqr比较
        float maxDistSqr = _maxDistance * _maxDistance;
        Vector3 camPos = cam.transform.position;

        for (int i = 0; i < candidatesRenderers.Count; i++)
        {
            var r = candidatesRenderers[i];
            
            if (r == null) 
                continue;

            // 1. 层级剔除 (Unity GameObject Layer)
            if (((1 << r.gameObject.layer) & _hideLayerMask.value) != 0)
                continue;

            // 2. 距离剔除
            float d2 = (r.transform.position - camPos).sqrMagnitude;
            if (d2 > maxDistSqr) 
                continue;

            _selectedRenderers.Add(r);
        }

        // 3. 排序
        _selectedRenderers.Sort((a, b) =>
        {
            float da = (a.transform.position - camPos).sqrMagnitude;
            float db = (b.transform.position - camPos).sqrMagnitude;
            return da.CompareTo(db);
        });

        // 4. 截断
        if (_selectedRenderers.Count > _maxTargets)
            _selectedRenderers.RemoveRange(_maxTargets, _selectedRenderers.Count - _maxTargets);

        ActiveCount = _selectedRenderers.Count;
    }

    private void UpdateMatricesAndAtlas(Camera cam)
    {
        //初始化
        for (int i = ActiveCount; i < 10; i++)
        {
            ViewMatrices[i] = Matrix4x4.identity;
            ProjMatrices[i] = Matrix4x4.identity;
            WorldToShadowAtlasMatrices[i] = Matrix4x4.identity;
            UVClamp[i] = Vector4.zero;
            TileViewport[i] = new Rect(0, 0, 0, 0);
        }

        Vector3 lightDir = mainLight.transform.forward; 
        Matrix4x4 lightViewMatrix = GetMainLightViewMatrix(lightDir, cam.transform.position);

        for (int i = 0; i < ActiveCount; i++)
        {
            var r = _selectedRenderers[i];
            Bounds b = r.bounds;

            ComputeMinMaxInViewSpace(lightViewMatrix, b,
                out float xmin, out float xmax,
                out float ymin, out float ymax,
                out float zmin, out float zmax);

            xmin -= _xyPadding; xmax += _xyPadding;
            ymin -= _xyPadding; ymax += _xyPadding;

            float near = Mathf.Max(0.01f, -zmax - _depthPadding);
            float far  = Mathf.Max(near + 0.1f, -zmin + _depthPadding);

            Matrix4x4 projectionMatrix = Matrix4x4.Ortho(xmin, xmax, ymin, ymax, near, far);

            ViewMatrices[i] = lightViewMatrix;
            ProjMatrices[i] = projectionMatrix;

            GetTileRect(i, out int offX, out int offY);

            TileViewport[i] = new Rect(
                offX + _shadowAtlasTileBorderPixels,
                offY + _shadowAtlasTileBorderPixels,
                _shadowAtlasTileSize - _shadowAtlasTileBorderPixels * 2,
                _shadowAtlasTileSize - _shadowAtlasTileBorderPixels * 2
            );

            Matrix4x4 worldToShadowTexMatrix = GetWorldToShadowTexMatrixGPU(projectionMatrix, lightViewMatrix);
            Matrix4x4 tileScaleOffsetMatrix = GetTileScaleOffsetMatrix(offX, offY, _shadowAtlasTileSize, _shadowAtlasSize, _shadowAtlasSize);

            WorldToShadowAtlasMatrices[i] = tileScaleOffsetMatrix * worldToShadowTexMatrix;

            float uMin = (offX + _shadowAtlasTileBorderPixels) / (float)_shadowAtlasSize;
            float uMax = (offX + _shadowAtlasTileSize - _shadowAtlasTileBorderPixels) / (float)_shadowAtlasSize;
            float vMin = (offY + _shadowAtlasTileBorderPixels) / (float)_shadowAtlasSize;
            float vMax = (offY + _shadowAtlasTileSize - _shadowAtlasTileBorderPixels) / (float)_shadowAtlasSize;
            UVClamp[i] = new Vector4(uMin, uMax, vMin, vMax);
        }
    }

    // 辅助函数
    
    private void GetTileRect(int index, out int offsetX, out int offsetY)
    {
        int column = index % _shadowAtlasTileColumns;
        int row = index / _shadowAtlasTileColumns;
        offsetX = column * _shadowAtlasTileSize;
        offsetY = row * _shadowAtlasTileSize;
    }
    
    private Matrix4x4 GetMainLightViewMatrix(Vector3 lightDirWS, Vector3 cameraPosWS)
    {
        Vector3 lightPos = cameraPosWS - lightDirWS.normalized * _lightCameraBackDistance;
        Vector3 forward = lightDirWS.normalized;
        Vector3 upRef = Mathf.Abs(Vector3.Dot(forward, Vector3.up)) > 0.99f ? Vector3.forward : Vector3.up;
        Vector3 right = Vector3.Cross(forward, upRef).normalized; 
        Vector3 up = Vector3.Cross(right, forward).normalized;    
        Matrix4x4 view = Matrix4x4.identity;
        view.SetRow(0, new Vector4(right.x, right.y, right.z, -Vector3.Dot(right, lightPos)));
        view.SetRow(1, new Vector4(up.x, up.y, up.z, -Vector3.Dot(up, lightPos)));
        Vector3 back = -forward; 
        view.SetRow(2, new Vector4(back.x, back.y, back.z, -Vector3.Dot(back, lightPos)));
        view.SetRow(3, new Vector4(0, 0, 0, 1));
        return view;
    }

    private static void ComputeMinMaxInViewSpace(Matrix4x4 view, Bounds b, out float xmin, out float xmax, out float ymin, out float ymax, out float zmin, out float zmax)
    {
        Vector3 c = b.center;
        Vector3 e = b.extents;
        Vector3[] corners = {
            c + new Vector3(-e.x, -e.y, -e.z), c + new Vector3(-e.x, -e.y,  e.z),
            c + new Vector3(-e.x,  e.y, -e.z), c + new Vector3(-e.x,  e.y,  e.z),
            c + new Vector3( e.x, -e.y, -e.z), c + new Vector3( e.x, -e.y,  e.z),
            c + new Vector3( e.x,  e.y, -e.z), c + new Vector3( e.x,  e.y,  e.z),
        };
        xmin = ymin = zmin = float.PositiveInfinity;
        xmax = ymax = zmax = float.NegativeInfinity;
        for (int i = 0; i < 8; i++) 
        {
            Vector3 v = view.MultiplyPoint3x4(corners[i]);
            xmin = Mathf.Min(xmin, v.x); xmax = Mathf.Max(xmax, v.x);
            ymin = Mathf.Min(ymin, v.y); ymax = Mathf.Max(ymax, v.y);
            zmin = Mathf.Min(zmin, v.z); zmax = Mathf.Max(zmax, v.z);
        }
    }

    private static Matrix4x4 GetWorldToShadowTexMatrixGPU(Matrix4x4 proj, Matrix4x4 view)
    {
        Matrix4x4 gpuProj = GL.GetGPUProjectionMatrix(proj, true);
        Matrix4x4 texScaleBias = new Matrix4x4();
        if (SystemInfo.usesReversedZBuffer) 
        {
            texScaleBias.SetRow(0, new Vector4(0.5f, 0.0f, 0.0f, 0.5f));
            texScaleBias.SetRow(1, new Vector4(0.0f, 0.5f, 0.0f, 0.5f));
            texScaleBias.SetRow(2, new Vector4(0.0f, 0.0f, -1.0f, 1.0f));
            texScaleBias.SetRow(3, new Vector4(0.0f, 0.0f, 0.0f, 1.0f));
        }
        else
        {
            texScaleBias.SetRow(0, new Vector4(0.5f, 0.0f, 0.0f, 0.5f));
            texScaleBias.SetRow(1, new Vector4(0.0f, 0.5f, 0.0f, 0.5f));
            texScaleBias.SetRow(2, new Vector4(0.0f, 0.0f, 0.5f, 0.5f));
            texScaleBias.SetRow(3, new Vector4(0.0f, 0.0f, 0.0f, 1.0f));
        }
        return texScaleBias * gpuProj * view;
    }

    private static Matrix4x4 GetTileScaleOffsetMatrix(int offsetX, int offsetY, int tileSize, int atlasWidth, int atlasHeight)
    {
        float sx = (float)tileSize / atlasWidth;    // scale U
        float sy = (float)tileSize / atlasHeight;   // scale V
        float tx = (float)offsetX / atlasWidth;     // translate U
        float ty = (float)offsetY / atlasHeight;    // translate V
        
        Matrix4x4 tileScaleOffsetMatrix = new Matrix4x4();
        tileScaleOffsetMatrix.SetRow(0, new Vector4(sx, 0.0f, 0.0f, tx));
        tileScaleOffsetMatrix.SetRow(1, new Vector4(0.0f, sy, 0.0f, ty));
        tileScaleOffsetMatrix.SetRow(2, new Vector4(0.0f, 0.0f, 1.0f, 0.0f));
        tileScaleOffsetMatrix.SetRow(3, new Vector4(0.0f, 0.0f, 0.0f, 1.0f));
        return tileScaleOffsetMatrix;
    }
    
    public Renderer GetActiveRenderer(int index)
    {
        if (index >= 0 && index < _selectedRenderers.Count) 
            return _selectedRenderers[index];
        
        return null;
    }
    
    //Debug
    private void DebugDrawLightOrthoRanges()
    {
    #if UNITY_EDITOR
        const bool kEnableDebug = true;
    #else
        const bool kEnableDebug = false;
    #endif
        if (!kEnableDebug) return;

        int count = ActiveCount;
        if (count <= 0) return;

        for (int i = 0; i < count; i++)
        {
            Matrix4x4 view = ViewMatrices[i];
            Matrix4x4 proj = ProjMatrices[i];

            if (proj == Matrix4x4.identity) 
                continue;

            float left   = (-proj.m03 - 1f) / proj.m00;
            float right  = ( 1f - proj.m03) / proj.m00;
            float bottom = (-proj.m13 - 1f) / proj.m11;
            float top    = ( 1f - proj.m13) / proj.m11;
            float near   = ( proj.m23 + 1f) / proj.m22;
            float far    = ( proj.m23 - 1f) / proj.m22;

            float zNear = -near;
            float zFar  = -far;

            Matrix4x4 invView = view.inverse;

            Vector3 nbl = invView.MultiplyPoint3x4(new Vector3(left,  bottom, zNear));
            Vector3 nbr = invView.MultiplyPoint3x4(new Vector3(right, bottom, zNear));
            Vector3 ntr = invView.MultiplyPoint3x4(new Vector3(right, top,    zNear));
            Vector3 ntl = invView.MultiplyPoint3x4(new Vector3(left,  top,    zNear));

            Vector3 fbl = invView.MultiplyPoint3x4(new Vector3(left,  bottom, zFar));
            Vector3 fbr = invView.MultiplyPoint3x4(new Vector3(right, bottom, zFar));
            Vector3 ftr = invView.MultiplyPoint3x4(new Vector3(right, top,    zFar));
            Vector3 ftl = invView.MultiplyPoint3x4(new Vector3(left,  top,    zFar));

            const float duration = 0f;
            const bool depthTest = false;

            Debug.DrawLine(nbl, nbr, Color.green, duration, depthTest);
            Debug.DrawLine(nbr, ntr, Color.green, duration, depthTest);
            Debug.DrawLine(ntr, ntl, Color.green, duration, depthTest);
            Debug.DrawLine(ntl, nbl, Color.green, duration, depthTest);

            Debug.DrawLine(fbl, fbr, Color.cyan, duration, depthTest);
            Debug.DrawLine(fbr, ftr, Color.cyan, duration, depthTest);
            Debug.DrawLine(ftr, ftl, Color.cyan, duration, depthTest);
            Debug.DrawLine(ftl, fbl, Color.cyan, duration, depthTest);

            Debug.DrawLine(nbl, fbl, Color.yellow, duration, depthTest);
            Debug.DrawLine(nbr, fbr, Color.yellow, duration, depthTest);
            Debug.DrawLine(ntr, ftr, Color.yellow, duration, depthTest);
            Debug.DrawLine(ntl, ftl, Color.yellow, duration, depthTest);
        }
    }
}