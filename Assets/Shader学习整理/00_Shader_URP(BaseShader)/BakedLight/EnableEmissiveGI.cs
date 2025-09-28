using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

#if UNITY_EDITOR
[ExecuteInEditMode]
public class EnableEmissiveGI : MonoBehaviour
{
     public enum CustomMaterialGlobalIlluminationFlags
     {
         None = 0,
         RealtimeEmissive = 1,
         BakedEmissive = 2,
         EmissiveIsBlack = 4,
     }

    public CustomMaterialGlobalIlluminationFlags flags = 0;
    void Start()
    {
        CheckEmissiveMode();
    }

    private void OnValidate()
    {
        CheckEmissiveMode();
    }

    void CheckEmissiveMode()
    {
        var renderer = GetComponent<Renderer>();
        if (renderer == null) 
            return;

        foreach (var mat in renderer.sharedMaterials)
        {
            if (mat == null) continue;
            mat.globalIlluminationFlags = (MaterialGlobalIlluminationFlags)flags;
        }
    }

}
#endif
