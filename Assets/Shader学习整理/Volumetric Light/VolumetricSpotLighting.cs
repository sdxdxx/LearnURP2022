using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.GlobalIllumination;

[ExecuteAlways]
public class VolumetricSpotLighting : MonoBehaviour
{
    [Range(0f,0.2f)]public float StartRadius = 0;

    public float FalloffInnerRate = 0;
    private Material VolumetricMaterial;
    private Light spotLight;

    private float range = 0;
    
    void Start()
    {
        Shader shader = Shader.Find("URP/VolumetricLighting");
        spotLight = gameObject.GetComponent<Light>();
        VolumetricMaterial = new Material(shader); //gameObject.GetComponent<MeshRenderer>().sharedMaterial;
        gameObject.GetComponent<Renderer>().material = VolumetricMaterial;
        UpdateMaterial();
    }
    
    void UpdateMaterial()
    {
        float ra = StartRadius;
        float spotAngle = spotLight.spotAngle * Mathf.Deg2Rad;
        range = spotLight.range*Mathf.Cos(spotAngle*0.5f);
        float rb = range * Mathf.Tan(spotAngle*0.5f);
        Vector3 pa = transform.position;
        Vector3 pb = transform.position + spotLight.transform.forward * range;
        transform.localScale = new Vector3(rb * 2,rb * 2,spotLight.range);
        
        VolumetricMaterial.SetFloat("_RadiusA", ra);
        VolumetricMaterial.SetFloat("_RadiusB", rb);
        VolumetricMaterial.SetFloat("_SpotRange", range);
        VolumetricMaterial.SetVector("_PositonA", pa);
        VolumetricMaterial.SetVector("_PositonB", pb);
        VolumetricMaterial.SetFloat("_InnerRate",FalloffInnerRate);
        
        VolumetricMaterial.SetColor("_BaseColor",spotLight.color);
        VolumetricMaterial.SetFloat("_LightIntensity",spotLight.intensity);
    }
    
    // Update is called once per frame
    void Update()
    {
        if (!gameObject.isStatic)
        {
            UpdateMaterial();
        }
    }
}
