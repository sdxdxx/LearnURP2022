using System.Collections;
using System.Collections.Generic;
using UnityEditor.Rendering;
using UnityEngine;

[ExecuteAlways]
public class InteractiveGrass : MonoBehaviour
{
    public Transform[] characterPos = new Transform[8];
    private Vector4[] interactiveCharacterPos = new Vector4[8];
    public Material material;
    void Update()
    {
        for (int i = 0; i < interactiveCharacterPos.Length; i++)
        {
            if (characterPos[i])
            {
                interactiveCharacterPos[i] = characterPos[i].position;
            }
        }
        
        Shader.SetGlobalVectorArray("_interactiveCharacterPos",interactiveCharacterPos);
        Shader.SetGlobalVector("_playerPos",interactiveCharacterPos[0]);
    }
}
