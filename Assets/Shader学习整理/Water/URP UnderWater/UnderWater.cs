using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class UnderWater : MonoBehaviour
{
    Vector4[] corners = new Vector4[4];
    
    // Update is called once per frame
    void Update()
    {
        // 左下
        corners[0] = Camera.main.ViewportToWorldPoint(new Vector3(0.0f, 0.0f, Camera.main.nearClipPlane));
        // 右下
        corners[1] = Camera.main.ViewportToWorldPoint(new Vector3(1.0f, 0.0f, Camera.main.nearClipPlane));
        // 左上
        corners[2] = Camera.main.ViewportToWorldPoint(new Vector3(0.0f, 1.0f, Camera.main.nearClipPlane));
        // 右上
        corners[3] = Camera.main.ViewportToWorldPoint(new Vector3(1.0f, 1.0f, Camera.main.nearClipPlane));

        Shader.SetGlobalVectorArray("_ViewPortPos",corners);
        Shader.SetGlobalFloat("_WaterPlaneHeight",transform.position.y);
    }
}
