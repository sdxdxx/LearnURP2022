using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;
using UnityEngine.UI;

 public class Flash : BaseMeshEffect
 {
     [HideInInspector]public bool EnableDebugMode = false;
     [HideInInspector]public bool EnableAddMode = true;
     [HideInInspector]public bool EnableCustomMask = false;
     [HideInInspector]public Texture CustomMask;
     [HideInInspector][Range(0.5f,2.0f)]public float CustomMaskScale = 1.0f;
     [HideInInspector][Range(0,1)]public float FlashWidth = 0.26f;
     [HideInInspector][Range(0,1)]public float FlashSmooth = 0.5f;
     [HideInInspector][ColorUsageAttribute(true, true)] public Color FlashColor = Color.white;
     [HideInInspector][Range(0,1)]public float FlashIntensity = 1.0f;
     [HideInInspector][Range(0,1)]public float AlphaCullValue = 0.0f;
     [HideInInspector][Range(0,1)]public float Angle = 0.0f;
     [HideInInspector][Range(0,1)]public float Offset = 0.5f;
     [HideInInspector][Range(0,30)]public float FlashTime = 10.0f;
     [HideInInspector][Range(0,30)]public float DelayTime = 2.5f;
        
    private static List<UIVertex> m_VetexList = new List<UIVertex>();
    private Vector4 vertexMinAndMax;
 
    protected override void Start()
    {
        base.Start();

        var shader = Shader.Find("Custom/2D/Flash");
        base.graphic.material = new Material(shader);

        
        var v1 = base.graphic.canvas.additionalShaderChannels;
        var v2 = AdditionalCanvasShaderChannels.TexCoord1;
        if ((v1 & v2) != v2)
        {
            base.graphic.canvas.additionalShaderChannels |= v2;
        }
        v2 = AdditionalCanvasShaderChannels.TexCoord2;
        if ((v1 & v2) != v2)
        {
            base.graphic.canvas.additionalShaderChannels |= v2;
        }

        this.Refresh();
    }
        
#if UNITY_EDITOR
     protected override void OnValidate()
     {
         base.OnValidate();
         if (base.graphic.material != null)
         {
             this.Refresh();
         }
     }
#endif
     
        public void Refresh()
        {
            if(CustomMask)
                CustomMask.wrapMode = TextureWrapMode.Clamp;
            
            base.graphic.material.SetTexture("_CustomMask", CustomMask);
            base.graphic.material.SetFloat("_CustomMaskScale",CustomMaskScale);
            base.graphic.material.SetFloat("_Width", FlashWidth);
            base.graphic.material.SetFloat("_Smooth", FlashSmooth);
            base.graphic.material.SetColor("_FlashColor", FlashColor);
            base.graphic.material.SetFloat("_AlphaCullValue", AlphaCullValue);
            base.graphic.material.SetFloat("_Angle", Angle);
            base.graphic.material.SetFloat("_Offset", Offset);
            base.graphic.material.SetFloat("_FlashIntensity", FlashIntensity);
            base.graphic.material.SetFloat("_FlashTime", FlashTime);
            base.graphic.material.SetFloat("_DelayTime", DelayTime);
            
            if (EnableDebugMode)
            {
                base.graphic.material.EnableKeyword("_EnableDebugMode");
            }
            else
            {
                base.graphic.material.DisableKeyword("_EnableDebugMode");
            }

            if (EnableAddMode)
            {
                base.graphic.material.EnableKeyword("_EnableAddMode");
            }
            else
            {
                base.graphic.material.DisableKeyword("_EnableAddMode");
            }

            if (EnableCustomMask)
            {
                base.graphic.material.EnableKeyword("_EnableCustomMask");
            }
            else
            {
                base.graphic.material.DisableKeyword("_EnableCustomMask");
            }
            
            base.graphic.SetVerticesDirty();
        }
 
        public override void ModifyMesh(VertexHelper vh)
        {
            vh.GetUIVertexStream(m_VetexList);
            
            this.ProcessVertices();
            
            vh.Clear();
            vh.AddUIVertexTriangleStream(m_VetexList);
            
        }
        
        private void ProcessVertices()
        {
            float minPosX = m_VetexList[0].position.x;
            float maxPosX = m_VetexList[0].position.x;
            float minPosY = m_VetexList[0].position.y;
            float maxPosY = m_VetexList[0].position.y;

            for (int i = 0; i < m_VetexList.Count; i++)
            {
                minPosX = Mathf.Min(minPosX, m_VetexList[i].position.x);
                maxPosX = Mathf.Max(maxPosX, m_VetexList[i].position.x);
                minPosY = Mathf.Min(minPosY, m_VetexList[i].position.y);
                maxPosY = Mathf.Max(maxPosY, m_VetexList[i].position.y);
            }
            
            for (int i = 0; i < m_VetexList.Count; i++)
            {
               var currentVertex = m_VetexList[i];
               
               currentVertex.uv1.x = (currentVertex.position.x - minPosX)/(maxPosX - minPosX);
               currentVertex.uv1.y = (currentVertex.position.y - minPosY)/(maxPosY - minPosY);
               
               m_VetexList[i] = currentVertex;
            }
            
        }
     
 }
 