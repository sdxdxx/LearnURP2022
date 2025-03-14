using UnityEngine;

/// <summary>
/// 自由相机移动控制
/// </summary>
[RequireComponent(typeof(Camera))]
public class FreelyCameraMoveController : MonoBehaviour
{
    public float speed = 4.0f;
    public float shiftSpeed = 16.0f;
    public bool showInstructions = true;

    private Vector3 startEulerAngles;
    private Vector3 startMousePosition;
    private float realTime;

    void OnEnable()
    {
        realTime = Time.realtimeSinceStartup;
    }

    void Update()
    {
        float forward = 0.0f;
        if (Input.GetKey(KeyCode.W) || Input.GetKey(KeyCode.UpArrow))
        {
            forward += 1.0f;
        }

        if (Input.GetKey(KeyCode.S) || Input.GetKey(KeyCode.DownArrow))
        {
            forward -= 1.0f;
        }

        float up = 0.0f;
        if (Input.GetKey(KeyCode.E))
        {
            up += 1.0f;
        }

        if (Input.GetKey(KeyCode.Q))
        {
            up -= 1.0f;
        }

        float right = 0.0f;
        if (Input.GetKey(KeyCode.D) || Input.GetKey(KeyCode.RightArrow))
        {
            right += 1.0f;
        }

        if (Input.GetKey(KeyCode.A) || Input.GetKey(KeyCode.LeftArrow))
        {
            right -= 1.0f;
        }

        float currentSpeed = speed;
        if (Input.GetKey(KeyCode.LeftShift) || Input.GetKey(KeyCode.RightShift))
        {
            currentSpeed = shiftSpeed;
        }

        float realTimeNow = Time.realtimeSinceStartup;
        float deltaRealTime = realTimeNow - realTime;
        realTime = realTimeNow;

        Vector3 delta = new Vector3(right, up, forward) * currentSpeed * deltaRealTime;

        transform.position += transform.TransformDirection(delta);

        Vector3 mousePosition = Input.mousePosition;

        if (Input.GetMouseButtonDown(1))
        {
            startMousePosition = mousePosition;
            startEulerAngles = transform.localEulerAngles;
        }

        if (Input.GetMouseButton(1))
        {
            Vector3 offset = mousePosition - startMousePosition;
            transform.localEulerAngles = startEulerAngles + new Vector3(-offset.y * 360.0f / Screen.height,
                offset.x * 360.0f / Screen.width, 0.0f);
        }
    }


    //-------------------------------------------------
    void OnGUI()
    {
        if (showInstructions)
        {
            GUI.Label(new Rect(10.0f, 10.0f, 600.0f, 400.0f),
                "WASD 前后左右移动相机\n " +
                "EQ 上升、降低相机高度\n" +
                "鼠标右键旋转相机\n");
        }
    }
}