using System;
using UnityEditor;
using UnityEngine;
 
[CustomEditor(typeof(Flash))]
public class Flash_Editor : Editor
{
    private bool isChineseMode;
    public override void OnInspectorGUI()
    {
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
        
        base.OnInspectorGUI();
        
        Flash t = (Flash)target;

        if (isChineseMode)
        {
            // Debug
            GUILayout.Label("调试");
            EditorGUI.indentLevel++;
            t.EnableDebugMode = EditorGUILayout.Toggle("启用调试模式", t.EnableDebugMode);
            if (t.EnableDebugMode)
                t.Offset = EditorGUILayout.Slider("流光偏移 (仅用于调试)",t.Offset, 0.0f, 1.0f);
            EditorGUI.indentLevel--;
            
            EditorGUILayout.Space(10);
            
            //Mask
            GUILayout.Label("遮罩");
            EditorGUI.indentLevel++;
            t.EnableCustomMask = EditorGUILayout.Toggle("启用自定义流光遮罩", t.EnableCustomMask);
            if (t.EnableCustomMask)
            {
                t.CustomMask = EditorGUILayout.ObjectField("自定义流光遮罩",t.CustomMask, typeof(Texture), false) as Texture;
                t.CustomMaskScale = EditorGUILayout.Slider("Scale",t.CustomMaskScale,0.5f,2.0f);
            }
            else
            {
                t.FlashWidth = EditorGUILayout.Slider("流光遮罩宽度",t.FlashWidth, 0.0f, 1.0f);
                t.FlashSmooth = EditorGUILayout.Slider("流光遮罩边缘软度",t.FlashSmooth, 0.0f, 1.0f);
            }
            EditorGUI.indentLevel--;
            
            EditorGUILayout.Space(10);
            
            //Mask Settings
            GUILayout.Label("遮罩其它参数设置");
            EditorGUI.indentLevel++;
            
            //Add Mode
            t.EnableAddMode = EditorGUILayout.Toggle("启用相加叠加模式", t.EnableAddMode);
            
            GUIContent FlashColorContent = new GUIContent("流光颜色");
            t.FlashColor = EditorGUILayout.ColorField(FlashColorContent,t.FlashColor,false,false,true);
            t.FlashIntensity = EditorGUILayout.Slider("流光强度",t.FlashIntensity, 0.0f, 1.0f);
            t.AlphaCullValue = EditorGUILayout.Slider("透明剔除",t.AlphaCullValue, 0.0f, 1.0f);
            t.Angle = EditorGUILayout.Slider("流光遮罩旋转角度",t.Angle, 0.0f, 1.0f);
            EditorGUI.indentLevel--;
            
            EditorGUILayout.Space(10);
            
            //Time
            GUILayout.Label("时间设置");
            EditorGUI.indentLevel++;
            t.FlashTime = EditorGUILayout.Slider("流光移动时间",t.FlashTime, 0.0f, 30.0f);
            t.DelayTime = EditorGUILayout.Slider("流光移动间隔时间",t.DelayTime, 0.0f, 30.0f);
            EditorGUI.indentLevel--;

            EditorGUI.EndChangeCheck();
        }
        else
        {
            // Debug
            GUILayout.Label("Debug");
            EditorGUI.indentLevel++;
            t.EnableDebugMode = EditorGUILayout.Toggle("Enable Debug Mode", t.EnableDebugMode);
            if (t.EnableDebugMode)
                t.Offset = EditorGUILayout.Slider("Flash Offset (Debug Only)",t.Offset, 0.0f, 1.0f);
            EditorGUI.indentLevel--;
            
            EditorGUILayout.Space(10);
            
            //Mask
            GUILayout.Label("Flash Mask");
            EditorGUI.indentLevel++;
            t.EnableCustomMask = EditorGUILayout.Toggle("Enable Custom Flash Mask", t.EnableCustomMask);
            if (t.EnableCustomMask)
            {
                t.CustomMask = EditorGUILayout.ObjectField("Custom Flash Mask",t.CustomMask, typeof(Texture), false) as Texture;
                t.CustomMaskScale = EditorGUILayout.Slider("Scale",t.CustomMaskScale,0.5f,2.0f);
            }
            else
            {
                t.FlashWidth = EditorGUILayout.Slider("Flash Mask Width",t.FlashWidth, 0.0f, 1.0f);
                t.FlashSmooth = EditorGUILayout.Slider("Flash Mask Smoothness",t.FlashSmooth, 0.0f, 1.0f);
            }
            EditorGUI.indentLevel--;
            
            EditorGUILayout.Space(10);
            
            //Mask Settings
            GUILayout.Label("Other Flash Mask Settings");
            EditorGUI.indentLevel++;
            
            //Add Mode
            t.EnableAddMode = EditorGUILayout.Toggle("Enable Add Mode", t.EnableAddMode);
            
            GUIContent FlashColorContent = new GUIContent("Flash Color (HDR)");
            t.FlashColor = EditorGUILayout.ColorField(FlashColorContent,t.FlashColor,false,false,true);
            t.FlashIntensity = EditorGUILayout.Slider("Flash Intensity",t.FlashIntensity, 0.0f, 1.0f);
            t.AlphaCullValue = EditorGUILayout.Slider("Alpha Cull Value",t.AlphaCullValue, 0.0f, 1.0f);
            t.Angle = EditorGUILayout.Slider("Flash Mask Rotation Angle",t.Angle, 0.0f, 1.0f);
            EditorGUI.indentLevel--;
            
            EditorGUILayout.Space(10);
            
            //Time
            GUILayout.Label("Time Settings");
            EditorGUI.indentLevel++;
            t.FlashTime = EditorGUILayout.Slider("Flash Time",t.FlashTime, 0.0f, 30.0f);
            t.DelayTime = EditorGUILayout.Slider("Flash Delay Time",t.DelayTime, 0.0f, 30.0f);
            EditorGUI.indentLevel--;

            EditorGUI.EndChangeCheck();
        }
        
        
        
        EditorGUILayout.Space(5);
        
        if (GUI.changed)
        {
            t.Refresh();
        }
    }
    

    
}