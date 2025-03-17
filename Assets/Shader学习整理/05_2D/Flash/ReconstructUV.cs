using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;
using UnityEngine.UI;

 public class ReconstructUV : BaseMeshEffect
 {
    private static List<UIVertex> m_VetexList = new List<UIVertex>();
    private Vector4 vertexMinAndMax;
 
    protected override void Start()
    {
        base.Start();
        
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
 