using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

[ExecuteAlways]
public class FlashForAnimation : MonoBehaviour
{
    [SerializeField][Range(0,1)]public float offset;
    private SpriteRenderer spriteRenderer;
    private Image image;
    private RawImage rawImage;
    
    Material material;
    void Start()
    {
        spriteRenderer = gameObject.GetComponent<SpriteRenderer>();
        image = gameObject.GetComponent<Image>();
        rawImage = gameObject.GetComponent<RawImage>();
        if (image)
        {
            material = image.material;
        }
        else if (spriteRenderer)
        {
            material = spriteRenderer.sharedMaterial;
        }
        else if (rawImage)
        {
            material = rawImage.material;
        }
    }

    void Update()
    {
        material.SetFloat("_Offset", offset);
    }
}
