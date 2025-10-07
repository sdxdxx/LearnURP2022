using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class CloudsBox : MonoBehaviour
{
    void Update()
    {
        Shader.SetGlobalVector("_CloudsPos",transform.position);
        Shader.SetGlobalVector("_CloudsBound",transform.localScale);
    }
}
