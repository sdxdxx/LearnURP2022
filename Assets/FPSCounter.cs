using UnityEngine;

public class FPSCounter : MonoBehaviour
{
#if UNITY_EDITOR || DEVELOPMENT_BUILD
    float smoothDelta;
    float fps, ms;
    GUIStyle style, shadow;
    int fontSize;
    Vector2 margin = new Vector2(12f, 8f); // 右/上边距

    void Awake()
    {
        DontDestroyOnLoad(gameObject);
        style = new GUIStyle { alignment = TextAnchor.UpperRight };
        style.normal.textColor = Color.white;

        shadow = new GUIStyle(style);
        shadow.normal.textColor = new Color(0f, 0f, 0f, 0.6f); // 阴影
    }

    void Update()
    {
        smoothDelta += (Time.unscaledDeltaTime - smoothDelta) * 0.1f;
        fps = 1f / Mathf.Max(1e-6f, smoothDelta);
        ms  = 1000f / fps;

        if (Input.GetKeyDown(KeyCode.F1) ||
            (Input.touchCount >= 3 && Input.GetTouch(0).phase == TouchPhase.Began))
            enabled = !enabled;
    }

    void OnGUI()
    {
        fontSize = Mathf.RoundToInt(Screen.height * 0.025f);
        style.fontSize = shadow.fontSize = fontSize;

        string text = $"{fps:0.} FPS  {ms:0.0} ms";

        // 顶部安全区域（适配刘海/打孔）
        Rect safe = Screen.safeArea;

        // 计算文本尺寸并锚在安全区右上角
        Vector2 size = style.CalcSize(new GUIContent(text));
        float x = safe.x + safe.width  - size.x - margin.x;
        float y = safe.y + margin.y;
        Rect rect = new Rect(x, y, size.x, size.y);

        // 阴影 + 正文
        GUI.Label(new Rect(rect.x + 1, rect.y + 1, rect.width, rect.height), text, shadow);
        GUI.Label(rect, text, style);
    }
#endif
}