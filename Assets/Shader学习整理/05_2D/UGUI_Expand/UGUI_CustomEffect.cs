using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;
using UnityEngine.UI;

 public class UGUI_CustomEffect : BaseMeshEffect
 {

        [HideInInspector]public bool IsText = false;

        [Header("Gradient Settings")] 
        public bool EnableGradient = false;
        [HideInInspector]public bool EnableVertexColorMode = false;
        public Color GradientColor1 = Color.red;//左上
        public Color GradientColor2 = Color.green;//右上
        public Color GradientColor3 = Color.blue;//左下
        public Color GradientColor4 = Color.yellow;//右下
        [Range(0f,1f)]public float GradientRange = 0.5f;
        [Range(0f,1f)]public float GradientSmoothRange = 0.1f;
        [Range(0f,1f)]public float GradientIntensity = 1.0f;
        [Range(0f,1f)]public float GradientRotation = 0.0f;
        
        [Header("Outline Settings")]
        public bool EnableOutline = false;
        [ColorUsageAttribute(true, true)] public Color OutlineColor = Color.white;
        [Range(0, 10)]
        public float OutlineWidth = 0;

        [Header("Shadow Settings")] 
        public bool EnableShadow = false;
        private float ShadowScale = 1.0f;
        public Vector2 ShadowOffset = new Vector4(0, 0);
        public Color ShadowColor = Color.black;
        
        [Header("Underline Settings")]
        [Header("是否显示下划线")]
        public bool EnableUnderline = false;
        [Header("下划线宽度"), Range(0f, 100f), SerializeField]
        public float UnderlineHeight = 1.5f;
        private float UnderlineHeightHalf = 0.75f;
        public float UnderlineOffset = 0;
        public Color32 UnderlineColor = Color.white;
        private Text text;
        private UICharInfo[] characters;
        private UILineInfo[] lines;
        private Color[] gradientColors;
        private char[] textChars;
        
        // 可视的字符个数
        private int characterCountVisible = 0;
        private UIVertex[] underlineUIVertexs = new UIVertex[6];
        
        private static List<UIVertex> m_VetexList = new List<UIVertex>();

        private Vector4 vertexMinAndMax;
        
        override protected void Awake()
        {
            this.text = this.GetComponent<Text>();
            if (this.text == null) return;
            text.RegisterDirtyMaterialCallback(OnFontMaterialChanged);
        }
#if UNITY_EDITOR
        override protected void OnEnable()
        {
            this.text = this.GetComponent<Text>();
            if (this.text == null) return;
            text.RegisterDirtyMaterialCallback(OnFontMaterialChanged);
        }
#endif

        private void OnFontMaterialChanged()
        {
            // font纹理发生变化时,在font中注册一个字符
            text.font.RequestCharactersInTexture("*", text.fontSize, text.fontStyle);
        }
        
 
        protected override void Start()
        {
            base.Start();
 
            var shader = Shader.Find("URP/2D/UGUI/CustomEffect");
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
            IsText = gameObject.GetComponent<Text>();

            EnableVertexColorMode = IsText;
            
            base.graphic.material.SetFloat("_GradientIntensity",this.GradientIntensity);
            base.graphic.material.SetColor("_GradientColor1", this.GradientColor1);
            base.graphic.material.SetColor("_GradientColor2", this.GradientColor2);
            base.graphic.material.SetFloat("_GradientRange", this.GradientRange);
            base.graphic.material.SetFloat("_GradientSmoothRange", this.GradientSmoothRange);
            base.graphic.material.SetFloat("_GradientRotation", this.GradientRotation);
            
            base.graphic.material.SetColor("_OutlineColor", this.OutlineColor);
            base.graphic.material.SetFloat("_OutlineWidth", this.OutlineWidth);
            base.graphic.material.SetVector("_ShadowOffset",this.ShadowOffset);
            base.graphic.material.SetColor("_ShadowColor",this.ShadowColor);
            base.graphic.material.SetFloat("_ShadowScale", this.ShadowScale);
            
            base.graphic.material.SetColor("_UnderlineColor", this.UnderlineColor);
            
            base.graphic.material.SetVector("_VertexMinAndMax", this.vertexMinAndMax);
            

            if (IsText)
            {
                base.graphic.material.EnableKeyword("_IsText");
            }
            else
            {
                base.graphic.material.DisableKeyword("_IsText");
            }
            
            if (EnableGradient)
            {
                base.graphic.material.EnableKeyword("_EnableGradient");
            }
            else
            {
                base.graphic.material.DisableKeyword("_EnableGradient");
            }

            if (EnableVertexColorMode)
            {
                base.graphic.material.EnableKeyword("_EnableVertexColorMode");
            }
            else
            {
                base.graphic.material.DisableKeyword("_EnableVertexColorMode");
            }
            
            if (EnableOutline)
            {
                base.graphic.material.EnableKeyword("_EnableOutline");
            }
            else
            {
                base.graphic.material.DisableKeyword("_EnableOutline");
            }

            if (EnableShadow)
            {
                base.graphic.material.EnableKeyword("_EnableShadow");
            }
            else
            {
                base.graphic.material.DisableKeyword("_EnableShadow");
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
            
            float vertexMinX = m_VetexList[0].position.x;
            float vertexMaxX = m_VetexList[0].position.x;
            float vertexMinY = m_VetexList[0].position.y;
            float vertexMaxY = m_VetexList[0].position.y;
            
            for (int i = 0; i < m_VetexList.Count; i += 3)
            {
                var v1 = m_VetexList[i];
                var v2 = m_VetexList[i + 1];
                var v3 = m_VetexList[i + 2];
                
                // 计算原顶点坐标中心点
                var minX = _Min(v1.position.x, v2.position.x, v3.position.x);
                var minY = _Min(v1.position.y, v2.position.y, v3.position.y);
                var maxX = _Max(v1.position.x, v2.position.x, v3.position.x);
                var maxY = _Max(v1.position.y, v2.position.y, v3.position.y);
                var posCenter = new Vector2(minX + maxX, minY + maxY) * 0.5f;
                
                // 计算原始顶点坐标和UV的方向
                Vector2 triX, triY, uvX, uvY;
                Vector2 pos1 = v1.position;
                Vector2 pos2 = v2.position;
                Vector2 pos3 = v3.position;
                if (Mathf.Abs(Vector2.Dot((pos2 - pos1).normalized, Vector2.right))
                    > Mathf.Abs(Vector2.Dot((pos3 - pos2).normalized, Vector2.right)))
                {
                    triX = pos2 - pos1;
                    triY = pos3 - pos2;
                    uvX = v2.uv0 - v1.uv0;
                    uvY = v3.uv0 - v2.uv0;
                }
                else
                {
                    triX = pos3 - pos2;
                    triY = pos2 - pos1;
                    uvX = v3.uv0 - v2.uv0;
                    uvY = v2.uv0 - v1.uv0;
                }
                
                // 计算原始UV框
                var uvMin = _Min(v1.uv0, v2.uv0, v3.uv0);
                var uvMax = _Max(v1.uv0, v2.uv0, v3.uv0);
                var uvOriginMinaAndMax = new Vector4(uvMin.x, uvMin.y, uvMax.x, uvMax.y);

                float width = 0;

                if (EnableOutline)
                {
                    width += this.OutlineWidth;
                }
                
                // 为每个顶点设置新的Position和UV，并传入原始UV框
                v1 = _SetNewPosAndUV(v1, width, posCenter, triX, triY, uvX, uvY, uvOriginMinaAndMax);
                v2 = _SetNewPosAndUV(v2, width, posCenter, triX, triY, uvX, uvY, uvOriginMinaAndMax);
                v3 = _SetNewPosAndUV(v3, width, posCenter, triX, triY, uvX, uvY, uvOriginMinaAndMax);
                
                
                 vertexMinX = Mathf.Min(_Min(v1.position.x, v2.position.x, v3.position.x),vertexMinX); 
                 vertexMinY = Mathf.Min(_Min(v1.position.y, v2.position.y, v3.position.y),vertexMinY);
                 vertexMaxX = Mathf.Max(_Max(v1.position.x, v2.position.x, v3.position.x),vertexMaxX); 
                 vertexMaxY = Mathf.Max( _Max(v1.position.y, v2.position.y, v3.position.y),vertexMaxY);
                 
                 vertexMinAndMax = new Vector4(vertexMinX, vertexMinY, vertexMaxX, vertexMaxY);
                 
                 // 应用设置后的UIVertex
                 m_VetexList[i] = v1;
                 m_VetexList[i + 1] = v2;
                 m_VetexList[i + 2] = v3;
                 
            }
            
            
            vertexMinAndMax = new Vector4(vertexMinX, vertexMinY, vertexMaxX, vertexMaxY);

            if (EnableGradient&&EnableVertexColorMode)
            {
                for (int i = 0; i < m_VetexList.Count; i += 6)
                {
                    var v1 = m_VetexList[i];
                    var v2 = m_VetexList[i + 1];
                    var v3 = m_VetexList[i + 2];
                    var v4 = m_VetexList[i + 3];
                    var v5 = m_VetexList[i + 4];
                    var v6 = m_VetexList[i + 5];
                    
                    v1.color = CopyColorRGB(v1.color, GradientColor1);
                    v2.color = CopyColorRGB(v2.color, GradientColor2);
                    v3.color = CopyColorRGB(v3.color, GradientColor4);
                    v4.color = CopyColorRGB(v4.color, GradientColor4);
                    v5.color = CopyColorRGB(v5.color, GradientColor3);
                    v6.color = CopyColorRGB(v6.color, GradientColor1);
                
                    // 应用设置后的UIVertex
                    m_VetexList[i] = v1;
                    m_VetexList[i + 1] = v2;
                    m_VetexList[i + 2] = v3;
                    m_VetexList[i + 3] = v4;
                    m_VetexList[i + 4] = v5;
                    m_VetexList[i + 5] = v6;
                }
            }
            
            // 添加下划线
            if (EnableUnderline)
            {
                this.UnderlineHeightHalf = this.UnderlineHeight * .5f;
                // cachedTextGenerator是当前实际显示出来的相关信息,cachedTextGeneratorForLayout是所有布局信息(包括看不到的)
                this.characters = text.cachedTextGenerator.GetCharactersArray();
                this.lines = text.cachedTextGenerator.GetLinesArray();
                this.textChars = this.text.text.ToCharArray();
                // 使用characterCountVisible来得到真正显示的字符数量.characterCount会额外包含(在宽度不足)时候裁剪掉的(边缘)字符,会导致显示的下划线多一个空白的宽度
                this.characterCountVisible = text.cachedTextGenerator.characterCountVisible;
                
                this.DrawAllLinesLine();
            }
        }
 
 
        private static UIVertex _SetNewPosAndUV(UIVertex pVertex, float pOutLineWidth,
            Vector2 pPosCenter,
            Vector2 pTriangleX, Vector2 pTriangleY,
            Vector2 pUVX, Vector2 pUVY,
            Vector4 pUVOriginMinAndMax)
        {
            // Position
            var pos = pVertex.position;
            var posXOffset = pos.x > pPosCenter.x ? pOutLineWidth : -pOutLineWidth;
            var posYOffset = pos.y > pPosCenter.y ? pOutLineWidth : -pOutLineWidth;
            pos.x += posXOffset;
            pos.y += posYOffset;
            pVertex.position = pos;
            
            // UV
            var uv = pVertex.uv0;
            var uvXY= new Vector2(uv.x,uv.y);
            var uvZW= new Vector2(uv.z,uv.w);
            uvXY += pUVX / pTriangleX.magnitude * posXOffset * (Vector2.Dot(pTriangleX, Vector2.right) > 0 ? 1 : -1);
            uvXY += pUVY / pTriangleY.magnitude * posYOffset * (Vector2.Dot(pTriangleY, Vector2.up) > 0 ? 1 : -1);
            pVertex.uv0 = new Vector4(uvXY.x,uvXY.y,uvZW.x,uvZW.y);
            
            // 原始UV框
            pVertex.uv1 = pUVOriginMinAndMax;
 
            return pVertex;
        }
        
        // 从font纹理中获取指定字符的uv
        private Vector2 GetUnderlineCharUV(Text text)
        {
            CharacterInfo info;
            if (text.font.GetCharacterInfo('*', out info, text.fontSize, text.fontStyle))
            {
                return (info.uvBottomLeft + info.uvBottomRight + info.uvTopLeft + info.uvTopRight) * 0.25f;
            }
            Debug.LogWarning("GetCharacterInfo failed");
            return Vector2.zero;
        }
        
        // 显示所有下划线
        private void DrawAllLinesLine()
        {
            var uv0 = this.GetUnderlineCharUV(text);
            for (int i = 0; i < this.lines.Length; i++)
            {
                var line = this.lines[i];
                var endIndex = 0;
                if (i + 1 < this.lines.Length)
                {
                    // 通过下一行的起始索引减1得到这一行最后一个字符索引位置
                    var nextLineStartCharIdx = this.lines[i + 1].startCharIdx;
                    // 与本行的相同,当文本宽度只够容纳一个字的时候,unity会产生一个空行,要排除改行
                    if (nextLineStartCharIdx == this.lines[i].startCharIdx) continue;

                    endIndex = nextLineStartCharIdx - 1;
                }
                else
                {
                    // 最后一行的最后字符索引位置
                    if (this.characterCountVisible == 0) continue;
                    endIndex = this.characterCountVisible - 1;
                }

                var bottomY = this.GetLineBottomY(i);

                var firstCharOff = line.startCharIdx;
                this.AddUnderlineVertTriangle(line.startCharIdx, endIndex, firstCharOff, bottomY, uv0);
            }
        }

        private float GetLineBottomY(int lineIndex)
        {
            UILineInfo line = this.lines[lineIndex];
            var bottomY = line.topY -  line.height - UnderlineOffset;
            
            // bottomY是原始大小下的信息,但文本在不同分辨率下会被进一步缩放处理,所以要将比例带入计算
            bottomY /= this.text.pixelsPerUnit;
            return bottomY;
        }

        private Vector2 GetCharCursorPos(int charIdx, float firstCharOff)
        {
            var charInfo = this.characters[charIdx];
            var cursorPos = charInfo.cursorPos;
            // cursorPos是原始大小下的信息,但文本在不同分辨率下会被进一步缩放处理,所以要将比例带入计算
            cursorPos /= this.text.pixelsPerUnit;

            var rtf = (this.transform as RectTransform);
            return cursorPos;
        }
        
        private void AddUnderlineVertTriangle(int startIndex, int endIndex, float firstCharOff, float bottomY, Vector2 uv0)
        {
            if (this.textChars[endIndex] == '\n')
            {
                // 跳过换行符
                endIndex--;
            }
            if (endIndex < startIndex) return;

            // 左上
            var pos0 = new Vector3(this.GetCharCursorPos(startIndex, firstCharOff).x, bottomY + this.UnderlineHeightHalf, 0);

            // 左下, 向下扩展
            var pos1 = new Vector3(pos0.x, pos0.y - this.UnderlineHeight, 0);

            // 右下. charWidth是原始大小下的信息,但文本在不同分辨率下会被进一步缩放处理,所以要将比例带入计算
            var pos2 = new Vector3(this.GetCharCursorPos(endIndex, firstCharOff).x + characters[endIndex].charWidth / this.text.pixelsPerUnit, pos1.y, 0);

            // 右上
            var pos3 = new Vector3(pos2.x, pos0.y, 0);

            // 按照stream存储的规范,构建6个顶点: 左上和右下是2个三角形的重叠, 
            UIVertex vert = UIVertex.simpleVert;
            vert.color = this.UnderlineColor;
            vert.uv0 = new Vector4(uv0.x,uv0.y,7.0f,7.0f);

            vert.position = pos0;
            underlineUIVertexs[0] = vert;
            underlineUIVertexs[3] = vert;

            vert.position = pos1;
            underlineUIVertexs[5] = vert;

            vert.position = pos2;
            underlineUIVertexs[2] = vert;
            underlineUIVertexs[4] = vert;

            vert.position = pos3;
            underlineUIVertexs[1] = vert;

            m_VetexList.AddRange(underlineUIVertexs);
        }
 
 
        private static float _Min(float pA, float pB, float pC)
        {
            return Mathf.Min(Mathf.Min(pA, pB), pC);
        }
 
 
        private static float _Max(float pA, float pB, float pC)
        {
            return Mathf.Max(Mathf.Max(pA, pB), pC);
        }
        
        private static float _Min(float pA, float pB, float pC, float pD)
        {
            return Mathf.Min(Mathf.Min(pA, pB), Mathf.Min(pC,pD));
        }
 
 
        private static float _Max(float pA, float pB, float pC, float pD)
        {
            return Mathf.Max(Mathf.Max(pA, pB), Mathf.Max(pC,pD));
        }
 
 
        private static Vector2 _Min(Vector2 pA, Vector2 pB, Vector2 pC)
        {
            return new Vector2(_Min(pA.x, pB.x, pC.x), _Min(pA.y, pB.y, pC.y));
        }
 
 
        private static Vector2 _Max(Vector2 pA, Vector2 pB, Vector2 pC)
        {
            return new Vector2(_Max(pA.x, pB.x, pC.x), _Max(pA.y, pB.y, pC.y));
        }
        
        private static float _Min(float p1, float p2, float p3, float p4, float p5, float p6)
        {
            float temp1 = _Min(p1, p2, p3);
            float temp2 = _Min(p4, p5, p6);
            return Mathf.Min(temp1, temp2);
        }
        
        private static float _Max(float p1, float p2, float p3, float p4, float p5, float p6)
        {
            float temp1 = _Max(p1, p2, p3);
            float temp2 = _Max(p4, p5, p6);
            return Mathf.Max(temp1, temp2);
        }
        
        private Color CopyColorRGB( Color oldColor, Color newColor)
        {
            return new Color(newColor.r, newColor.g, newColor.b, oldColor.a);
        }
 }
 