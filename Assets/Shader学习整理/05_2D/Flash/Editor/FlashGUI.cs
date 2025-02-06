using UnityEngine;
using UnityEditor;
using System;

public class FlashGUI : ShaderGUI
{
    private bool isChineseMode = false;
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        Material targetMat = materialEditor.target as Material;
        
        //参数列表
        bool EnableDebugMode = Array.IndexOf(targetMat.shaderKeywords, "_EnableDebugMode") != -1;// 检查是否设置了 Debug Mode 并显示一个复选框
        bool EnableAddMode = Array.IndexOf(targetMat.shaderKeywords, "_EnableAddMode") != -1;// 检查是否设置了 Add Mode 并显示一个复选框
        bool EnableCustomMask = Array.IndexOf(targetMat.shaderKeywords, "_EnableCustomMask") != -1;// 检查是否设置了 Custom Mask 并显示一个复选框
        MaterialProperty CustomMask = FindProperty("_CustomMask", properties);
        MaterialProperty CustomMaskScale = FindProperty("_CustomMaskScale", properties);
        MaterialProperty FlashWidth = FindProperty("_Width", properties);
        MaterialProperty FlashSmooth = FindProperty("_Smooth", properties);
        MaterialProperty FlashColor = FindProperty("_FlashColor", properties);
        MaterialProperty FlashIntensity = FindProperty("_FlashIntensity", properties);
        MaterialProperty AlphaCullValue = FindProperty("_AlphaCullValue", properties);
        MaterialProperty Angle = FindProperty("_Angle", properties);
        MaterialProperty Offset = FindProperty("_Offset", properties);
        MaterialProperty FlashTime = FindProperty("_FlashTime", properties);
        MaterialProperty DelayTime = FindProperty("_DelayTime", properties);
        
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
        
        GUILayout.Space(20);

        if (isChineseMode)
        {
            //Debug Mode
            GUILayout.Label("调试");
            EditorGUI.indentLevel++;
            EnableDebugMode = EditorGUILayout.Toggle("启用调试模式", EnableDebugMode);
            if (EditorGUI.EndChangeCheck())
            {
                // 根据复选框来启用或禁用关键字
                if (EnableDebugMode)
                    targetMat.EnableKeyword("_EnableDebugMode");
                else
                    targetMat.DisableKeyword("_EnableDebugMode");
            }
            if (EnableDebugMode)
                materialEditor.ShaderProperty(Offset, "流光偏移 (仅用于调试)");
            EditorGUI.indentLevel--;
            
            EditorGUILayout.Space(10);
            
            //Mask
            GUILayout.Label("遮罩");
            EditorGUI.indentLevel++;
            EnableCustomMask = EditorGUILayout.Toggle("启用自定义流光遮罩", EnableCustomMask);
            if (EditorGUI.EndChangeCheck())
            {
                // 根据复选框来启用或禁用关键字
                if (EnableCustomMask)
                    targetMat.EnableKeyword("_EnableCustomMask");
                else
                    targetMat.DisableKeyword("_EnableCustomMask");
            }
            if (EnableCustomMask)
            {
                materialEditor.TexturePropertySingleLine(new GUIContent("自定义流光遮罩"), CustomMask,CustomMaskScale);
            }
            else
            {
                materialEditor.ShaderProperty(FlashWidth, "流光遮罩宽度");
                materialEditor.ShaderProperty(FlashSmooth, "流光遮罩边缘软度");
            }
            EditorGUI.indentLevel--;
            
            EditorGUILayout.Space(10);
            
            //Mask Settings
            GUILayout.Label("遮罩其它参数设置");
            EditorGUI.indentLevel++;
            
            //Add Mode
            EnableAddMode = EditorGUILayout.Toggle("启用相加叠加模式", EnableAddMode);
            if (EditorGUI.EndChangeCheck())
            {
                // 根据复选框来启用或禁用关键字
                if (EnableAddMode)
                    targetMat.EnableKeyword("_EnableAddMode");
                else
                    targetMat.DisableKeyword("_EnableAddMode");
            }
            
            materialEditor.ShaderProperty(FlashColor, "流光颜色 (HDR)");
            materialEditor.ShaderProperty(FlashIntensity, "流光强度");
            materialEditor.ShaderProperty(AlphaCullValue,"透明剔除");
            materialEditor.ShaderProperty(Angle, "流光遮罩旋转角度");
            EditorGUI.indentLevel--;
            
            EditorGUILayout.Space(10);
            
            //Time
            GUILayout.Label("时间设置");
            EditorGUI.indentLevel++;
            materialEditor.ShaderProperty(FlashTime, "流光移动时间");
            materialEditor.ShaderProperty(DelayTime, "流光移动间隔时间");
            EditorGUI.indentLevel--;

            EditorGUI.EndChangeCheck();
        }
        else
        {
            //Debug Mode
            GUILayout.Label("Debug");
            EditorGUI.indentLevel++;
            EnableDebugMode = EditorGUILayout.Toggle("Enable Debug Mode", EnableDebugMode);
            if (EditorGUI.EndChangeCheck())
            {
                // 根据复选框来启用或禁用关键字
                if (EnableDebugMode)
                    targetMat.EnableKeyword("_EnableDebugMode");
                else
                    targetMat.DisableKeyword("_EnableDebugMode");
            }
            if (EnableDebugMode)
                materialEditor.ShaderProperty(Offset, "Flash Offset (Debug Only)");
            EditorGUI.indentLevel--;
            
            EditorGUILayout.Space(10);
            
            //Mask
            GUILayout.Label("Flash Mask");
            EditorGUI.indentLevel++;
            EnableCustomMask = EditorGUILayout.Toggle("Enable Custom Flash Mask", EnableCustomMask);
            if (EditorGUI.EndChangeCheck())
            {
                // 根据复选框来启用或禁用关键字
                if (EnableCustomMask)
                    targetMat.EnableKeyword("_EnableCustomMask");
                else
                    targetMat.DisableKeyword("_EnableCustomMask");
            }
            if (EnableCustomMask)
            {
                //materialEditor.ShaderProperty(CustomMask, "Custom Flash Mask");
                materialEditor.TexturePropertySingleLine(new GUIContent("Custom Flash Mask"), CustomMask,CustomMaskScale);
                //materialEditor.ShaderProperty(CustomMaskScale,"Scale");
            }
            else
            {
                materialEditor.ShaderProperty(FlashWidth, "Flash Mask Width");
                materialEditor.ShaderProperty(FlashSmooth, "Flash Mask Smoothness");
            }
            EditorGUI.indentLevel--;
            
            EditorGUILayout.Space(10);
            
            //Mask Settings
            GUILayout.Label("Other Flash Mask Settings");
            EditorGUI.indentLevel++;
            
            //Add Mode
            EnableAddMode = EditorGUILayout.Toggle("Enable Add Mode", EnableAddMode);
            if (EditorGUI.EndChangeCheck())
            {
                // 根据复选框来启用或禁用关键字
                if (EnableAddMode)
                    targetMat.EnableKeyword("_EnableAddMode");
                else
                    targetMat.DisableKeyword("_EnableAddMode");
            }
            
            materialEditor.ShaderProperty(FlashColor, "Flash Color (HDR)");
            materialEditor.ShaderProperty(FlashIntensity, "Flash Intensity");
            materialEditor.ShaderProperty(AlphaCullValue,"Alpha Cull Value");
            materialEditor.ShaderProperty(Angle, "Flash Mask Rotation Angle");
            EditorGUI.indentLevel--;
            
            EditorGUILayout.Space(10);
            
            //Time
            GUILayout.Label("Time Settings");
            EditorGUI.indentLevel++;
            materialEditor.ShaderProperty(FlashTime, "Flash Time");
            materialEditor.ShaderProperty(DelayTime, "Flash Delay Time");
            EditorGUI.indentLevel--;

            EditorGUI.EndChangeCheck();
        }
        
        
        // 渲染默认 GUI
        base.OnGUI(materialEditor, properties);
    }
}