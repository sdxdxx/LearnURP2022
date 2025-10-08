using UnityEngine;
using System.Linq;

public class FramerateUnlocker : MonoBehaviour
{
//     [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
//     static void Uncap()
//     {
//         // 1) 不跟 vSync（移动端以 targetFrameRate 为准）
//         QualitySettings.vSyncCount = 0;
//
//         // 2) 要求设备最高刷新率（Unity 2021.2+ 支持小数 Hz）
// #if UNITY_2021_2_OR_NEWER
//         var res = Screen.resolutions;
//         if (res != null && res.Length > 0)
//         {
//             var best = res.OrderByDescending(r => (float)r.refreshRateRatio.value).First();
//             // 只改刷新率，分辨率保持当前
//             Screen.SetResolution(Screen.currentResolution.width,
//                 Screen.currentResolution.height,
//                 FullScreenMode.FullScreenWindow,
//                 best.refreshRateRatio);
//             Application.targetFrameRate = Mathf.CeilToInt((float)best.refreshRateRatio.value);
//         }
//         else
//         {
//             Application.targetFrameRate = 120; // 没有枚举结果就先给个高值
//         }
// #else
//         Application.targetFrameRate = Mathf.Max(Screen.currentResolution.refreshRate, 60);
// #endif
//
//         // 3) 其他不该限制帧率的开关
//         Screen.sleepTimeout = SleepTimeout.NeverSleep;
//         UnityEngine.Rendering.OnDemandRendering.renderFrameInterval = 1; // 不跳帧
//
//         Debug.Log($"[FramerateUnlocker] vSync={QualitySettings.vSyncCount}, " +
//                   $"target={Application.targetFrameRate}, " +
// #if UNITY_2021_2_OR_NEWER
//                   $"deviceHz={(float)Screen.currentResolution.refreshRateRatio.value:0.##}");
// #else
//                   $"deviceHz={Screen.currentResolution.refreshRate}");
// #endif
//     }
}