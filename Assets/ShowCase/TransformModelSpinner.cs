using UnityEngine;

[DisallowMultipleComponent]
public sealed class TransformModelSpinner : MonoBehaviour
{
    public enum SpeedMode
    {
        DegreesPerSecond,      // 按时间：度/秒（不受帧率影响）
        DegreesPerFrame,       // 按帧：度/帧（受帧率影响，但每帧固定）
        FramesPerRevolution360 // 按帧：N 帧转 360 度（每轴可单独设置）
    }

    [Header("Mode")]
    public SpeedMode speedMode = SpeedMode.DegreesPerSecond;

    [Header("Space")]
    [Tooltip("true=LocalRotation; false=World Rotation")]
    public bool useLocalSpace = true;

    [Header("Time")]
    [Tooltip("Only used in DegreesPerSecond mode.")]
    public bool useUnscaledTime = true;

    [Header("Speed Settings")]
    [Tooltip("Used in DegreesPerSecond mode. Unit: degrees/second.")]
    public Vector3 rotationSpeedDegreesPerSecond = new Vector3(0f, 30f, 0f);

    [Tooltip("Used in DegreesPerFrame mode. Unit: degrees/frame.")]
    public Vector3 rotationSpeedDegreesPerFrame = new Vector3(0f, 1f, 0f);

    [Tooltip("Used in FramesPerRevolution360 mode. Unit: frames/360 degrees. Set 0 to disable that axis.")]
    public Vector3 framesPerRevolution360 = new Vector3(0f, 60f, 0f);

    [Header("Runtime Controls")]
    [Tooltip("If true, the initial rotation is captured every time the component is enabled.")]
    public bool recaptureInitialOnEnable = true;

    private Quaternion m_InitialRotation;
    private Vector3 m_AccumulatedEulerDegrees;

    private void Awake()
    {
        CaptureInitialRotation();
        ResetAccumulation();
    }

    private void OnEnable()
    {
        if (recaptureInitialOnEnable)
            CaptureInitialRotation();

        ResetAccumulation();
    }

    private void Update()
    {
        Vector3 eulerStepDegrees = GetEulerStepDegrees();
        m_AccumulatedEulerDegrees += eulerStepDegrees;

        // 防止数值无限增长（可选，但推荐）
        m_AccumulatedEulerDegrees.x = Mathf.Repeat(m_AccumulatedEulerDegrees.x, 360f);
        m_AccumulatedEulerDegrees.y = Mathf.Repeat(m_AccumulatedEulerDegrees.y, 360f);
        m_AccumulatedEulerDegrees.z = Mathf.Repeat(m_AccumulatedEulerDegrees.z, 360f);

        Quaternion deltaRotation = Quaternion.Euler(m_AccumulatedEulerDegrees);

        if (useLocalSpace)
            transform.localRotation = m_InitialRotation * deltaRotation;
        else
            transform.rotation = m_InitialRotation * deltaRotation;
    }

    private Vector3 GetEulerStepDegrees()
    {
        switch (speedMode)
        {
            case SpeedMode.DegreesPerSecond:
            {
                float deltaTime = useUnscaledTime ? Time.unscaledDeltaTime : Time.deltaTime;
                return rotationSpeedDegreesPerSecond * deltaTime;
            }

            case SpeedMode.DegreesPerFrame:
                return rotationSpeedDegreesPerFrame;

            case SpeedMode.FramesPerRevolution360:
                return new Vector3(
                    FramesToStep(framesPerRevolution360.x),
                    FramesToStep(framesPerRevolution360.y),
                    FramesToStep(framesPerRevolution360.z)
                );

            default:
                return Vector3.zero;
        }
    }

    private static float FramesToStep(float framesFor360)
    {
        if (framesFor360 <= 0f)
            return 0f;

        return 360f / framesFor360; // 度/帧
    }

    private void CaptureInitialRotation()
    {
        m_InitialRotation = useLocalSpace ? transform.localRotation : transform.rotation;
    }

    private void ResetAccumulation()
    {
        m_AccumulatedEulerDegrees = Vector3.zero;
    }

    [ContextMenu("Capture Initial Rotation Now")]
    public void CaptureInitialRotationNow()
    {
        CaptureInitialRotation();
        ResetAccumulation();
    }

    [ContextMenu("Reset Rotation To Initial")]
    public void ResetToInitialRotation()
    {
        if (useLocalSpace)
            transform.localRotation = m_InitialRotation;
        else
            transform.rotation = m_InitialRotation;

        ResetAccumulation();
    }
}
