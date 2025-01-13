using System;
using UnityEditor;
using UnityEngine;
 
[CustomEditor(typeof(UGUI_CustomEffect))]
public class UGUI_CustomEffect_Editor : Editor
{
    //public float OutlineWidth = 0;
    public override void OnInspectorGUI()
    {
        //base.OnInspectorGUI();
        
        
        UGUI_CustomEffect t = (UGUI_CustomEffect)target;
        
        // Gradient Settings
        GUILayout.Label("渐变设置");
        t.EnableGradient = EditorGUILayout.Toggle("Enable Gradient", t.EnableGradient);
        if (t.EnableGradient)
        {
            EditorGUI.indentLevel++;
            t.EnableVertexColorMode = EditorGUILayout.Toggle("Enable Vertex Color Mode", t.EnableVertexColorMode);
            t.GradientColor1 = EditorGUILayout.ColorField("Gradient Color 1", t.GradientColor1);
            t.GradientColor2 = EditorGUILayout.ColorField("Gradient Color 2", t.GradientColor2);
            if (t.EnableVertexColorMode)
            {
                t.GradientColor3 = EditorGUILayout.ColorField("Gradient Color 3", t.GradientColor3);
                t.GradientColor4 = EditorGUILayout.ColorField("Gradient Color 4", t.GradientColor4);
            }
            else
            {
                t.GradientRange = EditorGUILayout.Slider("Gradient Range", t.GradientRange, 0.0f, 1.0f);
                t.GradientSmoothRange = EditorGUILayout.Slider("Gradient Smooth Range", t.GradientSmoothRange, 0.0f, 1.0f);
                t.GradientRotation = EditorGUILayout.Slider("Gradient Rotation", t.GradientRotation, 0.0f, 1.0f);
                t.GradientIntensity = EditorGUILayout.Slider("Gradient Intensity", t.GradientIntensity, 0.0f, 1.0f);
            }
            EditorGUI.indentLevel--;
        }
        
        EditorGUILayout.Space(5);
        
        // Outline Settings
        GUILayout.Label("外描边设置");
        t.EnableOutline = EditorGUILayout.Toggle("Enable Outline", t.EnableOutline);
        if (t.EnableOutline)
        {
            EditorGUI.indentLevel++;
            t.OutlineColor = EditorGUILayout.ColorField("Outline Color", t.OutlineColor);
            t.OutlineWidth = EditorGUILayout.Slider("Outline Width",t.OutlineWidth,0,10); //FloatField("Outline Width", t.OutlineWidth);
            EditorGUI.indentLevel--;
        }
        
        EditorGUILayout.Space(5);
        
        //Shadow Settings
        GUILayout.Label("阴影设置");
        t.EnableShadow = EditorGUILayout.Toggle("Enable Shadow", t.EnableShadow);
        if (t.EnableShadow)
        {
            EditorGUI.indentLevel++;
            t.ShadowColor = EditorGUILayout.ColorField("Shadow Color", t.ShadowColor);
            t.ShadowScale = EditorGUILayout.Slider("Shadow Scale", t.ShadowScale, 0.9f, 1.1f);
            t.ShadowOffset = EditorGUILayout.Vector2Field("Shadow Offset", t.ShadowOffset);
            EditorGUI.indentLevel--;
        }
        
        EditorGUILayout.Space(5);
        
        //Underline Settings
        GUILayout.Label("下划线设置");
        t.EnableUnderline = EditorGUILayout.Toggle("Enable Underline", t.EnableUnderline);
        if (t.EnableUnderline)
        {
            EditorGUI.indentLevel++;
            t.UnderlineHeight = EditorGUILayout.Slider("Underline Height", t.UnderlineHeight, 0.0f, 100.0f);
            t.UnderlineOffset = EditorGUILayout.FloatField("Underline Offset", t.UnderlineOffset);
            t.UnderlineColor = EditorGUILayout.ColorField("Underline Color", t.UnderlineColor);
            EditorGUI.indentLevel--;
        }
        
        if (GUI.changed)
        {
            t._Refresh();
        }
    }
    

    
}