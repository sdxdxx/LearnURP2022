using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class SunMatrix : MonoBehaviour
{
    private Matrix4x4 localToWorld;
   
    void Update()
    {
        localToWorld = transform.localToWorldMatrix;
        Shader.SetGlobalMatrix("_SunTransformMatrix",localToWorld);
    }
}