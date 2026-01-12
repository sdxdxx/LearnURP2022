using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;

[ExecuteAlways]
public class PerObjectShadowSystem : MonoBehaviour
{
    public static PerObjectShadowSystem Instance { get; private set; }

    [System.Serializable]
    public class RendererGroup
    {
        [Tooltip("Optional: used only for display / organization.")]
        public string groupName;

        [Tooltip("Optional: if you set this, you can rebuild the group from this root (see helper methods).")]
        public Transform root;

        [Tooltip("Renderers that are treated as ONE model (share ONE atlas tile).")]
        public List<Renderer> renderers = new List<Renderer>();
    }

    [Header("Scene References")]
    public Light mainLight;

    [Header("Auto Collect")]
    // NOTE: Each entry is treated as ONE model and occupies ONE shadow atlas tile.
    public List<RendererGroup> candidatesRenderers = new List<RendererGroup>();
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
    
    private int _shadowAtlasTileColumns = 1; 
    
    private int _shadowAtlasTileSize; //每个 tile 的像素宽高
    private int _shadowAtlasTileBorderPixels;//tile 边缘保留的像素边框，防止滤波/PCF 跨 tile 采到别人的内容

    private float _lightCameraBackDistance;
    private float _depthPadding;
    private float _xyPadding;

    // Output Data
    public int ActiveCount { get; private set; }//本帧被选中要投影的对象数量
    public readonly Matrix4x4[] ViewMatrices = new Matrix4x4[9];
    public readonly Matrix4x4[] ProjMatrices = new Matrix4x4[9];
    public readonly Matrix4x4[] WorldToShadowAtlasMatrices = new Matrix4x4[9];
    public readonly Vector4[] DepthRanges = new Vector4[9];
    public readonly Vector4[] UVClamp = new Vector4[9];
    public readonly Rect[] TileViewport = new Rect[9];

    private struct GroupSelection
    {
        public RendererGroup group;
        public Bounds bounds;
        public float distanceSqr;
    }

    private readonly List<GroupSelection> _selectionBuffer = new(32);
    private readonly List<RendererGroup> _selectedGroups = new(16);
    private readonly List<Bounds> _selectedGroupBounds = new(16);

    private void Awake()
    {
        Instance = this;
    }
    
    private void OnEnable()
    {
        Instance = this;

#if UNITY_EDITOR
        // 如果在编辑器模式下，代码重编译后，私有数据(ActiveCount等)丢了
        // 这里强制手动跑一遍核心逻辑，把数据恢复出来
        if (!Application.isPlaying)
        {
            // 1. 尝试获取相机 (因为编译后可能引用丢了)
            var cam = Camera.main;
            
            // 2. 只有当关键引用存在时才执行
            if (cam != null && mainLight != null && mainLight.type == LightType.Directional)
            {
                // 强制执行一次数据收集和计算
                if (autoCollectFromRoots) CollectCandidatesFromRoots();
                UpdateSelection(cam);
                UpdateMatricesAndAtlas();
                
                // 强制刷新一下 Scene 视图，确保 Debug 线条能画出来
                UnityEditor.SceneView.RepaintAll();
            }
        }
#endif
    }
    
    private void OnDisable()
    {
        if (Instance == this) Instance = null;
    }

    public void ApplySettings(PerObjectShadowFeature.Settings settings)
    {
        _hideLayerMask = settings.hideLayerMask;
        _maxDistance = settings.maxDistance;
        _maxTargets = settings.maxTargets;

        _shadowAtlasSize = settings.shadowAtlasSize;
        
        // 【优化】根据 maxTargets 自动计算分区列数
        // 1个目标->1x1; 2-4个目标->2x2; 5-9个目标->3x3; 10-16个目标->4x4
        _shadowAtlasTileColumns = Mathf.CeilToInt(Mathf.Sqrt(_maxTargets));
        
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
        if (mainLight == null) return;
        if (mainLight.type != LightType.Directional) return;

        if (autoCollectFromRoots)
            CollectCandidatesFromRoots();

        UpdateSelection(Camera.main);
        UpdateMatricesAndAtlas();
#if UNITY_EDITOR
        if(debugDraw)
            DebugDrawLightOrthoRanges();
#endif
    }

    private void CollectCandidatesFromRoots()
    {
        candidatesRenderers.Clear();

        for (int i = 0; i < candidateRoots.Count; i++)
        {
            Transform root = candidateRoots[i];
            if (root == null)
                continue;

            var group = new RendererGroup
            {
                groupName = root.name,
                root = root
            };

            var childRenderers = root.GetComponentsInChildren<Renderer>(includeInactive: false);
            for (int j = 0; j < childRenderers.Length; j++)
            {
                var r = childRenderers[j];
                if (r != null)
                    group.renderers.Add(r);
            }

            // Even if it's empty, keep it so you can see which root was collected.
            candidatesRenderers.Add(group);
        }
    }

    private void UpdateSelection(Camera cam)
    {
        _selectionBuffer.Clear();
        _selectedGroups.Clear();
        _selectedGroupBounds.Clear();

        float maxDistSqr = _maxDistance * _maxDistance;
        Vector3 camPos = cam.transform.position;

        for (int i = 0; i < candidatesRenderers.Count; i++)
        {
            RendererGroup g = candidatesRenderers[i];
            if (g == null)
                continue;

            if (!TryGetGroupBounds(g, out Bounds bounds))
                continue;

            // 距离剔除（使用 Bounds 最近点更稳定）
            Vector3 closest = bounds.ClosestPoint(camPos);
            float d2 = (closest - camPos).sqrMagnitude;
            if (d2 > maxDistSqr)
                continue;

            _selectionBuffer.Add(new GroupSelection
            {
                group = g,
                bounds = bounds,
                distanceSqr = d2
            });
        }

        // 排序（近的优先）
        _selectionBuffer.Sort((a, b) => a.distanceSqr.CompareTo(b.distanceSqr));

        // 截断
        int keepCount = Mathf.Min(_selectionBuffer.Count, _maxTargets);
        for (int i = 0; i < keepCount; i++)
        {
            _selectedGroups.Add(_selectionBuffer[i].group);
            _selectedGroupBounds.Add(_selectionBuffer[i].bounds);
        }

        ActiveCount = _selectedGroups.Count;
    }

    private void UpdateMatricesAndAtlas()
    {
        // 初始化未使用 slot
        for (int i = ActiveCount; i < ViewMatrices.Length; i++)
        {
            ViewMatrices[i] = Matrix4x4.identity;
            ProjMatrices[i] = Matrix4x4.identity;
            WorldToShadowAtlasMatrices[i] = Matrix4x4.identity;
            UVClamp[i] = Vector4.zero;
            TileViewport[i] = new Rect(0, 0, 0, 0);
        }
        
        
        for (int i = 0; i < ActiveCount; i++)
        {
            Bounds b = _selectedGroupBounds[i];

            Matrix4x4 lightViewMatrix = GetMainLightViewMatrix(mainLight, b.center);
            
            ComputeMinMaxInViewSpace(lightViewMatrix, b,
                out float xmin, out float xmax,
                out float ymin, out float ymax,
                out float zmin, out float zmax);

            xmin -= _xyPadding; xmax += _xyPadding;
            ymin -= _xyPadding; ymax += _xyPadding;
            
            float near = Mathf.Max(0.01f, -zmax - _depthPadding);
            float far  = Mathf.Max(near + 0.1f, -zmin + _depthPadding);
            float left = xmin;
            float right = xmax;
            float bottom = ymin;
            float top = ymax;

            float depthRange = Mathf.Abs(far - near);
            
            Matrix4x4 projectionMatrix = Matrix4x4.Ortho(left, right, bottom, top, near, far);

            DepthRanges[i] = new Vector4(depthRange,near,far,0);
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

    private void GetTileRect(int index, out int offsetX, out int offsetY)
    {
        int column = index % _shadowAtlasTileColumns;
        int row = index / _shadowAtlasTileColumns;
        offsetX = column * _shadowAtlasTileSize;
        offsetY = row * _shadowAtlasTileSize;
    }
    
    private Matrix4x4 GetMainLightViewMatrix(Light curLight, Vector3 targetPosWS)
    {
        
        // camera look direction (from camera to target)
        Vector3 forward = curLight.transform.forward;
        Vector3 right = curLight.transform.right;
        Vector3 up = curLight.transform.up;
        
        float dist = Mathf.Max(0.01f, Mathf.Abs(_lightCameraBackDistance));

        // 相机放在目标点的“上游”，朝 forward 方向看向目标
        Vector3 lightPos = targetPosWS - forward * dist;
        
        Vector3 xAxis = right; 
        Vector3 yAxis = up;
        Vector3 zAxis = -forward; 
        
        Matrix4x4 view = Matrix4x4.identity;
        view.SetRow(0, new Vector4(xAxis.x, xAxis.y, xAxis.z, -Vector3.Dot(xAxis, lightPos)));
        view.SetRow(1, new Vector4(yAxis.x, yAxis.y, yAxis.z, -Vector3.Dot(yAxis, lightPos)));
        view.SetRow(2, new Vector4(zAxis.x, zAxis.y, zAxis.z, -Vector3.Dot(zAxis, lightPos)));
        view.SetRow(3, new Vector4(0, 0, 0, 1));
        
#if UNITY_EDITOR
        if (debugDraw)
        {
            Debug.DrawLine(lightPos, targetPosWS, Color.magenta);
            Debug.DrawLine(lightPos, lightPos + xAxis*10 , Color.red);
            Debug.DrawLine(lightPos, lightPos + yAxis*10    , Color.green);
            Debug.DrawLine(lightPos, lightPos + zAxis*10 , Color.blue);
        }
#endif
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
        Matrix4x4 texScaleBias = new Matrix4x4();
        texScaleBias.SetRow(0, new Vector4(0.5f, 0.0f, 0.0f, 0.5f));
        texScaleBias.SetRow(1, new Vector4(0.0f, 0.5f, 0.0f, 0.5f));
        texScaleBias.SetRow(2, new Vector4(0.0f, 0.0f, 0.5f, 0.5f));
        texScaleBias.SetRow(3, new Vector4(0.0f, 0.0f, 0.0f, 1.0f));
        return texScaleBias * proj * view;
    }

    private static Matrix4x4 GetTileScaleOffsetMatrix(int offsetX, int offsetY, int tileSize, int atlasWidth, int atlasHeight)
    {
        float sx = (float)tileSize / atlasWidth;
        float sy = (float)tileSize / atlasHeight;
        float tx = (float)offsetX / atlasWidth;
        float ty = (float)offsetY / atlasHeight;

        Matrix4x4 tileScaleOffsetMatrix = new Matrix4x4();
        tileScaleOffsetMatrix.SetRow(0, new Vector4(sx, 0.0f, 0.0f, tx));
        tileScaleOffsetMatrix.SetRow(1, new Vector4(0.0f, sy, 0.0f, ty));
        tileScaleOffsetMatrix.SetRow(2, new Vector4(0.0f, 0.0f, 1.0f, 0.0f));
        tileScaleOffsetMatrix.SetRow(3, new Vector4(0.0f, 0.0f, 0.0f, 1.0f));
        return tileScaleOffsetMatrix;
    }

    public Renderer GetActiveRenderer(int index)
    {
        RendererGroup g = GetActiveGroup(index);
        if (g == null || g.renderers == null) return null;
        for (int i = 0; i < g.renderers.Count; i++)
        {
            if (g.renderers[i] != null)
                return g.renderers[i];
        }
        return null;
    }

    public RendererGroup GetActiveGroup(int index)
    {
        if (index >= 0 && index < _selectedGroups.Count)
            return _selectedGroups[index];
        return null;
    }

    public Bounds GetActiveGroupBounds(int index)
    {
        if (index >= 0 && index < _selectedGroupBounds.Count)
            return _selectedGroupBounds[index];
        return new Bounds(Vector3.zero, Vector3.zero);
    }

    private bool TryGetGroupBounds(RendererGroup group, out Bounds bounds)
    {
        bounds = default;
        if (group == null || group.renderers == null)
            return false;

        bool hasAny = false;

        for (int i = 0; i < group.renderers.Count; i++)
        {
            Renderer r = group.renderers[i];
            if (r == null)
                continue;

            if (!r.enabled || !r.gameObject.activeInHierarchy)
                continue;

            if (((1 << r.gameObject.layer) & _hideLayerMask.value) != 0)
                continue;

            if (!hasAny)
            {
                bounds = r.bounds;
                hasAny = true;
            }
            else
            {
                bounds.Encapsulate(r.bounds);
            }
        }

        return hasAny;
    }

    private void DebugDrawLightOrthoRanges()
    {
        int count = ActiveCount;
        if (count <= 0) return;
        
        for (int i = 0; i < count; i++)
        {
            Matrix4x4 view = ViewMatrices[i];
            Matrix4x4 proj = ProjMatrices[i];

            if (proj == Matrix4x4.identity)
                continue;

            // 1. 反推 X/Y (Standard NDC [-1, 1])
            float left   = (-proj.m03 - 1f) / proj.m00;
            float right  = ( 1f - proj.m03) / proj.m00;
            float bottom = (-proj.m13 - 1f) / proj.m11;
            float top    = ( 1f - proj.m13) / proj.m11;
            
            // 2. 反推 Z (Standard NDC [-1, 1])
            // Near 平面对应 NDC -1
            // Far  平面对应 NDC  1
            float zNear = (-1f - proj.m23) / proj.m22;
            float zFar  = ( 1f - proj.m23) / proj.m22;

            // 3. 还原到世界空间
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

            // 绿色 = 近平面
            Debug.DrawLine(nbl, nbr, Color.green, duration, depthTest);
            Debug.DrawLine(nbr, ntr, Color.green, duration, depthTest);
            Debug.DrawLine(ntr, ntl, Color.green, duration, depthTest);
            Debug.DrawLine(ntl, nbl, Color.green, duration, depthTest);

            // 青色 = 远平面
            Debug.DrawLine(fbl, fbr, Color.cyan, duration, depthTest);
            Debug.DrawLine(fbr, ftr, Color.cyan, duration, depthTest);
            Debug.DrawLine(ftr, ftl, Color.cyan, duration, depthTest);
            Debug.DrawLine(ftl, fbl, Color.cyan, duration, depthTest);

            // 黄色 = 连接线
            Debug.DrawLine(nbl, fbl, Color.yellow, duration, depthTest);
            Debug.DrawLine(nbr, fbr, Color.yellow, duration, depthTest);
            Debug.DrawLine(ntr, ftr, Color.yellow, duration, depthTest);
            Debug.DrawLine(ntl, ftl, Color.yellow, duration, depthTest);
        }
    }
}