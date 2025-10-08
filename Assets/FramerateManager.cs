using UnityEngine;

public class FramerateManager : MonoBehaviour
{
    public bool setNormalMode = true;
    public bool setMatchDisplay = false;
    public bool setUnlocked = false;
    public bool set30FPS = false;
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
    static void Boot()
    {
        var go = new GameObject("[FramerateManager]");
        go.hideFlags = HideFlags.DontSave;
        DontDestroyOnLoad(go);
        go.AddComponent<FramerateManager>();
    }

    void Start()
    {
        SetNormal();                   // 默认：恢复“正常”PC行为
        UnityEngine.Rendering.OnDemandRendering.renderFrameInterval = 1; // 不跳帧
    }

    void Update()
    {
        // 快捷键（Editor & Standalone 都可用）
        if (setNormalMode) SetNormal();
        if (setMatchDisplay) SetMatchDisplay();
        if (setUnlocked) SetUnlocked();
        if (set30FPS) Set30();
    }

    // ---- 模式实现 ----
    public static void SetNormal()
    {
        QualitySettings.vSyncCount = 1;      // 由显示器刷新率同步，避免撕裂
        Application.targetFrameRate = -1;    // 不手动限帧，交给 vSync
        //Log("Normal (vSync=1, target=-1)");
    }

    public static void SetMatchDisplay()
    {
        QualitySettings.vSyncCount = 0;      // 不跟 vSync
#if UNITY_2021_2_OR_NEWER
        int hz = Mathf.CeilToInt((float)Screen.currentResolution.refreshRateRatio.value);
#else
        int hz = Mathf.Max(60, Screen.currentResolution.refreshRate);
#endif
        Application.targetFrameRate = hz;    // 与当前显示器刷新率一致
        //Log($"MatchDisplay ({hz} Hz)");
    }

    public static void SetUnlocked()
    {
        QualitySettings.vSyncCount = 0;
        Application.targetFrameRate = 1000;  // 基本等于“无限制”，受硬件上限
        //Log("Unlocked (vSync=0, target=1000)");
    }

    public static void Set30()
    {
        QualitySettings.vSyncCount = 0;
        Application.targetFrameRate = 30;
        //Log("Force 30 (test)");
    }

//     static void Log(string mode)
//     {
// #if UNITY_EDITOR || DEVELOPMENT_BUILD
// #if UNITY_2021_2_OR_NEWER
//         float hz = (float)Screen.currentResolution.refreshRateRatio.value;
// #else
//         int hz = Screen.currentResolution.refreshRate;
// #endif
//         Debug.Log($"[FramerateManager] {mode} | deviceHz={hz:0.##} | target={Application.targetFrameRate} | vSync={QualitySettings.vSyncCount}");
// #endif
//     }
}
