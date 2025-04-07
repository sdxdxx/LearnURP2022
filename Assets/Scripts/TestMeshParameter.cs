using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

[ExecuteInEditMode]
public class TestMeshParameter : MonoBehaviour
{
    public Mesh mesh;
    public bool vertexMode = false;
    public bool colorMode = false;
    public bool tangentMode = false;
    public bool normalMode = false;
    public bool uv2Mode = false;

    public bool modifiedMesh = false;
    public float decodeValue = 10.0f;
    
    private void OnEnable()
    {
        Debug.Log("开始");
        var newColors = new List<Color>();
        if (mesh)
        {
            if (uv2Mode)
            {
                Debug.Log("UV2");
                if (modifiedMesh)
                {
                    for (int i = 0; i < mesh.vertexCount; i++)
                    {
                        Vector2 uv = mesh.uv3[i];
                        Vector2 uv2 = mesh.uv4[i];
                        uv.x = Mathf.Round((uv.x*2.0f- 1.0f)*decodeValue);
                        uv.y = Mathf.Round((uv.y*2.0f- 1.0f)*decodeValue);
                        uv2.x = Mathf.Round((uv2.x*2.0f- 1.0f)*decodeValue);
                        uv2.y = Mathf.Round((uv2.y*2.0f- 1.0f)*decodeValue);
                        Debug.Log(uv.x+","+uv.y+","+uv2.x+","+uv2.y);
                    }
                }
                else
                {
                    for (int i = 0; i < mesh.vertexCount; i++)
                    {
                        Vector2 uv = mesh.uv3[i];
                        Vector2 uv2 = mesh.uv4[i];
                        Debug.Log(uv.x+","+uv.y+","+uv2.x+","+uv2.y);
                    }
                }
                
            }
            
            if (vertexMode)
            {
                Debug.Log("Vertex");
                foreach (Vector3 v in mesh.vertices)
                {
                    
                    Debug.Log(v);
                }
            }

            if (colorMode)
            {
                Debug.Log("Vertex Color");
               
                
                if (modifiedMesh)
                {
                    foreach (Color color in mesh.colors)
                    {
                        Vector3 colorVec = new Vector3((color.r*2.0f- 1.0f)*decodeValue, (color.g*2.0f-1.0f)*decodeValue,(color.b*2.0f-1.0f)*decodeValue);
                        colorVec.x = Mathf.Round(colorVec.x);
                        colorVec.y = Mathf.Round(colorVec.y);
                        colorVec.z = Mathf.Round(colorVec.z);
                        Debug.Log("R: "+colorVec.x + " , " +"G: "+ colorVec.y + " , "+"B: " + colorVec.z);
                    }
                }
                else
                {
                    foreach (Color color in mesh.colors)
                    {
                        Debug.Log("R: "+color.r + " , " +"G: "+ color.g + " , "+"B: " + color.b);
                    }
                }
            }

            if (tangentMode)
            {
                Debug.Log("Tangent");
                foreach (Vector4 tangent in mesh.tangents)
                {
                    Debug.Log(tangent);
                }
            }
            
            if (normalMode)
            {
                Debug.Log("Normal");
                foreach (Vector4 normal in mesh.normals)
                {
                    Debug.Log(normal);
                }
            }
        }
        
        Debug.Log("结束");
    }
    
}
