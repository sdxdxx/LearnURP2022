using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class VolumetricSpotLighting : MonoBehaviour
{
    public float StartRadius = 0;
    public GameObject VolumetricBox;
    public Material VolumetricMaterial;
    public Light spotLight;

    private float range = 0;
    
    [ExecuteAlways]
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        float ra = StartRadius;
        float rb = range * Mathf.Tan(spotLight.spotAngle * 0.5f * Mathf.Deg2Rad);
        Vector3 pa = transform.position;
        Vector3 pb = transform.position + spotLight.transform.forward * range;
        range = spotLight.range;
        VolumetricBox.transform.localScale = new Vector3(rb * 2, range, rb * 2);
        VolumetricMaterial.SetFloat("_ra", ra);
        VolumetricMaterial.SetFloat("_rb", rb);
        VolumetricMaterial.SetVector("_pa", pa);
        VolumetricMaterial.SetVector("_pb", pb);
    }
    
}
