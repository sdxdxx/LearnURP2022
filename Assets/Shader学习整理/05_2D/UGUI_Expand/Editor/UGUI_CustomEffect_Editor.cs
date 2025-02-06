using System;
using UnityEditor;
using UnityEngine;
 
[CustomEditor(typeof(UGUI_CustomEffect))]
public class UGUI_CustomEffect_Editor : Editor
{
    private bool isChineseMode;
    
    public override void OnInspectorGUI()
    {
        //base.OnInspectorGUI();
        
        UGUI_CustomEffect t = (UGUI_CustomEffect)target;
        
        EditorGUI.BeginChangeCheck();
        GUILayout.BeginHorizontal();
        if(isChineseMode)
        {
            GUILayout.Box("中文", GUILayout.Width(100));
            if(GUILayout.Button("English",GUILayout.Width(100)))
            {
                isChineseMode = false;
            }
        }
        else
        {
            if (GUILayout.Button("中文", GUILayout.Width(100)))
            {
                isChineseMode = true;
            }
            GUILayout.Box("English", GUILayout.Width(100));
        }
        GUILayout.EndHorizontal();
        EditorGUI.EndChangeCheck();
        
        GUILayout.Space(20);

        if (isChineseMode)
        {
            // 渐变设置
            GUILayout.Label("渐变设置",EditorStyles.boldLabel);
            EditorGUI.indentLevel++;
            t.EnableGradient = EditorGUILayout.Toggle("启用渐变", t.EnableGradient);
            if (t.EnableGradient)
            {
                //t.EnableVertexColorMode = EditorGUILayout.Toggle("Enable Vertex Color Mode", t.EnableVertexColorMode);
                
                if (t.EnableVertexColorMode)
                {   
                    t.GradientColor1 = EditorGUILayout.ColorField("渐变颜色1（左上）", t.GradientColor1);
                    t.GradientColor2 = EditorGUILayout.ColorField("渐变颜色2（右上）", t.GradientColor2);
                    t.GradientColor3 = EditorGUILayout.ColorField("渐变颜色3（左下）", t.GradientColor3);
                    t.GradientColor4 = EditorGUILayout.ColorField("渐变颜色4（右下）", t.GradientColor4);
                }
                else
                {
                    t.GradientColor1 = EditorGUILayout.ColorField("渐变颜色1", t.GradientColor1);
                    t.GradientColor2 = EditorGUILayout.ColorField("渐变颜色2", t.GradientColor2);
                    t.GradientRange = EditorGUILayout.Slider("渐变范围", t.GradientRange, 0.0f, 1.0f);
                    t.GradientSmoothRange = EditorGUILayout.Slider("渐变平滑范围", t.GradientSmoothRange, 0.0f, 1.0f);
                    t.GradientRotation = EditorGUILayout.Slider("渐变旋转", t.GradientRotation, 0.0f, 1.0f);
                    t.GradientIntensity = EditorGUILayout.Slider("渐变强度", t.GradientIntensity, 0.0f, 1.0f);
                }
                
            }
            EditorGUI.indentLevel--;
            
            EditorGUILayout.Space(5);
            
            // 外描边设置
            GUILayout.Label("外描边设置",EditorStyles.boldLabel);
            EditorGUI.indentLevel++;
            t.EnableOutline = EditorGUILayout.Toggle("启用外描边", t.EnableOutline);
            if (t.EnableOutline)
            {
                t.OutlineColor = EditorGUILayout.ColorField("外描边颜色", t.OutlineColor);
                t.OutlineWidth = EditorGUILayout.Slider("外描边宽度",t.OutlineWidth,0,10); //FloatField("Outline Width", t.OutlineWidth);
            }
            EditorGUI.indentLevel--;
            
            EditorGUILayout.Space(5);
            
            //阴影设置
            GUILayout.Label("阴影设置",EditorStyles.boldLabel);
            EditorGUI.indentLevel++;
            t.EnableShadow = EditorGUILayout.Toggle("启用阴影", t.EnableShadow);
            if (t.EnableShadow)
            {
                t.ShadowColor = EditorGUILayout.ColorField("阴影颜色", t.ShadowColor);
                //t.ShadowScale = EditorGUILayout.FloatField("Shadow Scale", t.ShadowScale);
                t.ShadowOffset = EditorGUILayout.Vector2Field("阴影偏移", t.ShadowOffset);
            }
            EditorGUI.indentLevel--;
            
            EditorGUILayout.Space(5);
            
            //字体下划线设置
            if (t.IsText)
            {
                GUILayout.Label("下划线设置",EditorStyles.boldLabel);
                EditorGUI.indentLevel++;
                t.EnableUnderline = EditorGUILayout.Toggle("启用字体下划线", t.EnableUnderline);
                if (t.EnableUnderline)
                {
                    t.UnderlineHeight = EditorGUILayout.Slider("下划线高度", t.UnderlineHeight, 0.0f, 100.0f);
                    t.UnderlineOffset = EditorGUILayout.FloatField("下划线偏移", t.UnderlineOffset);
                    t.UnderlineColor = EditorGUILayout.ColorField("下划线颜色", t.UnderlineColor);
                }
                EditorGUI.indentLevel--;
            }
        }
        else
        {
            // Gradient Settings
            GUILayout.Label("Gradient Settings",EditorStyles.boldLabel);
            EditorGUI.indentLevel++;
            t.EnableGradient = EditorGUILayout.Toggle("Enable Gradient", t.EnableGradient);
            if (t.EnableGradient)
            {
                //t.EnableVertexColorMode = EditorGUILayout.Toggle("Enable Vertex Color Mode", t.EnableVertexColorMode);
                if (t.EnableVertexColorMode)
                {
                    t.GradientColor1 = EditorGUILayout.ColorField("Gradient Color 1 (Left Top)", t.GradientColor1);
                    t.GradientColor2 = EditorGUILayout.ColorField("Gradient Color 2 (Right Top)", t.GradientColor2);
                    t.GradientColor3 = EditorGUILayout.ColorField("Gradient Color 3 (Left Bottom)", t.GradientColor3);
                    t.GradientColor4 = EditorGUILayout.ColorField("Gradient Color 4 (Right Bottom)", t.GradientColor4);
                }
                else
                {
                    t.GradientColor1 = EditorGUILayout.ColorField("Gradient Color 1", t.GradientColor1);
                    t.GradientColor2 = EditorGUILayout.ColorField("Gradient Color 2", t.GradientColor2);
                    t.GradientRange = EditorGUILayout.Slider("Gradient Range", t.GradientRange, 0.0f, 1.0f);
                    t.GradientSmoothRange = EditorGUILayout.Slider("Gradient Smooth Range", t.GradientSmoothRange, 0.0f, 1.0f);
                    t.GradientRotation = EditorGUILayout.Slider("Gradient Rotation", t.GradientRotation, 0.0f, 1.0f);
                    t.GradientIntensity = EditorGUILayout.Slider("Gradient Intensity", t.GradientIntensity, 0.0f, 1.0f);
                }
                
            }
            EditorGUI.indentLevel--;
            
            EditorGUILayout.Space(5);
            
            // Outline Settings
            GUILayout.Label("Outline Settings",EditorStyles.boldLabel);
            EditorGUI.indentLevel++;
            t.EnableOutline = EditorGUILayout.Toggle("Enable Outline", t.EnableOutline);
            if (t.EnableOutline)
            {
                t.OutlineColor = EditorGUILayout.ColorField("Outline Color", t.OutlineColor);
                t.OutlineWidth = EditorGUILayout.Slider("Outline Width",t.OutlineWidth,0,10); //FloatField("Outline Width", t.OutlineWidth);
            }
            EditorGUI.indentLevel--;
            
            EditorGUILayout.Space(5);
            
            //Shadow Settings
            GUILayout.Label("Shadow Settings",EditorStyles.boldLabel);
            EditorGUI.indentLevel++;
            t.EnableShadow = EditorGUILayout.Toggle("Enable Shadow", t.EnableShadow);
            if (t.EnableShadow)
            {
                t.ShadowColor = EditorGUILayout.ColorField("Shadow Color", t.ShadowColor);
                //t.ShadowScale = EditorGUILayout.FloatField("Shadow Scale", t.ShadowScale);
                t.ShadowOffset = EditorGUILayout.Vector2Field("Shadow Offset", t.ShadowOffset);
            }
            EditorGUI.indentLevel--;
            
            EditorGUILayout.Space(5);
            
            //Underline Settings
            if (t.IsText)
            {
                GUILayout.Label("Underline Settings",EditorStyles.boldLabel);
                EditorGUI.indentLevel++;
                t.EnableUnderline = EditorGUILayout.Toggle("Enable Underline", t.EnableUnderline);
                if (t.EnableUnderline)
                {
                    t.UnderlineHeight = EditorGUILayout.Slider("Underline Height", t.UnderlineHeight, 0.0f, 100.0f);
                    t.UnderlineOffset = EditorGUILayout.FloatField("Underline Offset", t.UnderlineOffset);
                    t.UnderlineColor = EditorGUILayout.ColorField("Underline Color", t.UnderlineColor);
                }
                EditorGUI.indentLevel--;
            }
        }
        
        
        
        if (GUI.changed)
        {
            t._Refresh();
        }
    }
    

    
}