using UnityEngine;
using UnityEditor;
using System;

public class UniversalEffectGUI : ShaderGUI
{
    static bool Foldout(bool display, string title)
    {
        var style = new GUIStyle("ShurikenModuleTitle");
        style.font = new GUIStyle(EditorStyles.boldLabel).font;
        style.border = new RectOffset(15, 7, 4, 4);
        style.fixedHeight = 22;
        style.contentOffset = new Vector2(20f, -2f);
        style.fontSize = 11;
        style.normal.textColor = new Color(0.7f, 0.8f, 0.9f);
        
        var rect = GUILayoutUtility.GetRect(16f, 25f, style);
        GUI.Box(rect, title, style);

        var e = Event.current;

        var toggleRect = new Rect(rect.x + 4f, rect.y + 2f, 13f, 13f);
        if (e.type == EventType.Repaint)
        {
            EditorStyles.foldout.Draw(toggleRect, false, false, display, false);
        }

        if (e.type == EventType.MouseDown && rect.Contains(e.mousePosition))
        {
            display = !display;
            e.Use();
        }

        return display;
    }
    
    static bool MainTex_Foldout = false;
    static bool Distoration_Foldout = false;
    static bool Mask_Foldout = false;
    static bool Dissolve_Foldout = false;
    static bool Mode_Foldout = false;
    static bool Other_Foldout = false;
    static bool Instructions_Foldout = false;
    
    
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        //参数列表
        Material targetMat = materialEditor.target as Material;
        MaterialProperty BaseColor = FindProperty("_BaseColor", properties);
        MaterialProperty MainTex = FindProperty("_MainTex", properties);
        MaterialProperty USpeed_MainTex = FindProperty("_USpeed_MainTex", properties);
        MaterialProperty VSpeed_MainTex = FindProperty("_VSpeed_MainTex", properties);
        MaterialProperty PolarCoordinatesMovingSpeed = FindProperty("_PolarCoordinatesMovingSpeed", properties);
        MaterialProperty MainTexRotation = FindProperty("_MainTexRotation", properties);
        MaterialProperty Mask = FindProperty("_Mask", properties);
        MaterialProperty MaskRotation = FindProperty("_MaskRotation", properties);
        MaterialProperty ExtraMask = FindProperty("_ExtraMask", properties);
        MaterialProperty ExtraMaskRotation = FindProperty("_ExtraMaskRotation", properties);
        MaterialProperty DissolveMask = FindProperty("_DissolveMask", properties);
        MaterialProperty DissolveRange = FindProperty("_DissolveRange", properties);
        MaterialProperty DissolveSmoothness = FindProperty("_DissolveSmoothness", properties);
        MaterialProperty DissolveWidth = FindProperty("_DissolveWidth", properties);
        MaterialProperty DistortionMap = FindProperty("_DistortionMap", properties);
        MaterialProperty DistortionIntensity = FindProperty("_DistortionIntensity", properties);
        MaterialProperty DissolveEdgeColor = FindProperty("_DissolveEdgeColor", properties);
        MaterialProperty USpeed_Distortion = FindProperty("_USpeed_Distortion", properties);
        MaterialProperty VSpeed_Distortion = FindProperty("_VSpeed_Distortion", properties);
        MaterialProperty PolarCoordinatesMovingSpeed_Distoration = FindProperty("_PolarCoordinatesMovingSpeed_Distortion", properties);
        MaterialProperty DistortionMapRotation = FindProperty("_DistortionMapRotation", properties);
        MaterialProperty BlendSrc = FindProperty("_BlendSrc", properties);
        MaterialProperty BlendDst = FindProperty("_BlendDst", properties);
        MaterialProperty CullMode = FindProperty("_CullMode", properties);
        
        MaterialProperty EnableMainTexRotation_prop = FindProperty("_EnableMainTexRotation", properties);
        MaterialProperty EnableMaskR_prop = FindProperty("_EnableMaskR", properties);
        MaterialProperty EnableMaskRotation_prop = FindProperty("_EnableMaskRotation", properties);
        MaterialProperty EnableExtraMask_prop = FindProperty("_EnableExtraMask", properties);
        MaterialProperty EnableExtraMaskR_prop = FindProperty("_EnableExtraMaskR", properties);
        MaterialProperty EnableExtraMaskRotation_prop = FindProperty("_EnableExtraMaskRotation", properties);
        MaterialProperty EnableDissolve_prop = FindProperty("_EnableDissolve", properties);
        MaterialProperty EnableDissolveMaskR_prop = FindProperty("_EnableDissolveMaskR", properties);
        MaterialProperty EnableDissolveCustomData_prop = FindProperty("_EnableDissolveCustomData", properties);
        MaterialProperty EnableDistortion_prop = FindProperty("_EnableDistortion", properties);
        MaterialProperty EnableDissolveMaskDistortion_prop = FindProperty("_EnableDissolveMaskDistortion", properties);
        MaterialProperty EnableMainTexDistortion_prop = FindProperty("_EnableMainTexDistortion", properties);
        MaterialProperty EnableDistortionPolarCoordinates_prop = FindProperty("_EnableDistortionPolarCoordinates", properties);
        MaterialProperty EnableDistortionMapRotation_prop = FindProperty("_EnableDistortionMapRotation", properties);
        MaterialProperty EnablePolarCoordinates_prop = FindProperty("_EnablePolarCoordinates", properties);
        MaterialProperty EnableDissolveMaskPolarCoordinates_prop = FindProperty("_EnableDissolveMaskPolarCoordinates", properties);
        
        
        EditorGUI.BeginChangeCheck();

        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        MainTex_Foldout = Foldout(MainTex_Foldout, "主贴图");
        if (MainTex_Foldout)
        {
             //MainTex
            GUILayout.Label("主贴图", EditorStyles.boldLabel);
            EditorGUILayout.Space(5);
            EditorGUI.indentLevel++;
            materialEditor.TexturePropertySingleLine(new GUIContent("主贴图"), MainTex,BaseColor);
            materialEditor.TextureScaleOffsetProperty(MainTex);
            EditorGUILayout.Space(5);
            materialEditor.ShaderProperty(EnablePolarCoordinates_prop, "启用极坐标");
            bool EnablePolarCoordinates = EnablePolarCoordinates_prop.floatValue != 0;
            EditorGUILayout.Space(5);
            materialEditor.ShaderProperty(EnableMainTexRotation_prop, "启用主贴图旋转");
            bool EnableMainTexRotation = EnableMainTexRotation_prop.floatValue != 0;
            if (EnableMainTexRotation)
            {   
                materialEditor.ShaderProperty(MainTexRotation,"主贴图旋转");
            }
            EditorGUI.indentLevel--;
            EditorGUILayout.Space(10);
            
            
            GUILayout.Label("UV流动", EditorStyles.boldLabel);
            EditorGUI.indentLevel++;
            if (!EnablePolarCoordinates)
            {
                materialEditor.ShaderProperty(USpeed_MainTex, "U Speed");
                materialEditor.ShaderProperty(VSpeed_MainTex, "V Speed");
            }
            else
            {
                materialEditor.ShaderProperty(PolarCoordinatesMovingSpeed, "Speed");
            }
            
            
            EditorGUI.indentLevel--;
            
            EditorGUILayout.Space(10);
        }
        EditorGUILayout.EndVertical();

        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        Mask_Foldout = Foldout(Mask_Foldout, "遮罩");
        if (Mask_Foldout)
        {
            GUILayout.Label("遮罩", EditorStyles.boldLabel);
            EditorGUILayout.Space(5);
            EditorGUI.indentLevel++;
            EditorGUILayout.BeginHorizontal();
            materialEditor.TexturePropertySingleLine(new GUIContent("遮罩"), Mask);
            materialEditor.ShaderProperty(EnableMaskR_prop,"启用单通道R遮罩");
            bool EnableMaskR = EnableMaskR_prop.floatValue != 0;
            EditorGUILayout.EndHorizontal();
            materialEditor.TextureScaleOffsetProperty(Mask);
            EditorGUILayout.Space(5);
            materialEditor.ShaderProperty(EnableMaskRotation_prop,"启用遮罩旋转");
            bool EnableMaskRotation = EnableMaskRotation_prop.floatValue != 0;
            if (EnableMaskRotation)
            {
                materialEditor.ShaderProperty(MaskRotation,"遮罩旋转");
            }
            
            EditorGUILayout.Space(10);
            
            materialEditor.ShaderProperty(EnableExtraMask_prop,"启用额外遮罩");
            bool EnableExtraMask = EnableExtraMask_prop.floatValue != 0;
            if (EnableExtraMask)
            {
                EditorGUILayout.Space(5);
                EditorGUILayout.BeginHorizontal();
                materialEditor.TexturePropertySingleLine(new GUIContent("额外遮罩"), ExtraMask);
                materialEditor.ShaderProperty(EnableExtraMaskR_prop,"启用单通道R遮罩");
                bool EnableExtraMaskR = EnableExtraMaskR_prop.floatValue != 0;
                EditorGUILayout.EndHorizontal();
                materialEditor.TextureScaleOffsetProperty(ExtraMask);
                EditorGUILayout.Space(5);
                materialEditor.ShaderProperty(EnableExtraMaskRotation_prop,"启用额外遮罩旋转");
                bool EnableExtraMaskRotation = EnableExtraMaskRotation_prop.floatValue != 0;
                if (EnableExtraMaskRotation)
                {
                    materialEditor.ShaderProperty(ExtraMaskRotation,"额外遮罩旋转");
                }
            }
            EditorGUI.indentLevel--;
            
            EditorGUILayout.Space(10);
        }
        EditorGUILayout.EndVertical();
        
        
        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        Dissolve_Foldout = Foldout(Dissolve_Foldout, "溶解");
        if (Dissolve_Foldout)
        {
            GUILayout.Label("溶解", EditorStyles.boldLabel);
            EditorGUILayout.Space(5);
            EditorGUI.indentLevel++;
            materialEditor.ShaderProperty(EnableDissolve_prop,"启用溶解");
            bool EnableDissolve = EnableDissolve_prop.floatValue != 0;
            if (EnableDissolve)
            {
                EditorGUILayout.Space(5);
                EditorGUILayout.BeginHorizontal();
                materialEditor.TexturePropertySingleLine(new GUIContent("溶解遮罩"), DissolveMask);
                EditorGUILayout.EndHorizontal();
                materialEditor.TextureScaleOffsetProperty(DissolveMask);
                materialEditor.ShaderProperty(EnableDissolveMaskPolarCoordinates_prop,"启用极坐标");
                materialEditor.ShaderProperty(EnableDissolveMaskR_prop,"启用单通道R溶解遮罩");
                materialEditor.ShaderProperty(EnableDissolveCustomData_prop,"启用自定义数据");
                bool EnableDissolveMaskR = EnableDissolveMaskR_prop.floatValue != 0;
                bool EnableDissolveCustomData = EnableDissolveCustomData_prop.floatValue != 0;
                bool EnableDissolveMaskPolarCoordinates = EnableDissolveMaskPolarCoordinates_prop.floatValue != 0;
                if (!EnableDissolveCustomData)
                {
                    materialEditor.ShaderProperty(DissolveRange,"溶解程度");
                }
                else
                {
                    EditorGUILayout.LabelField("溶解程度 -> Custom Data X");
                }
            
                materialEditor.ShaderProperty(DissolveSmoothness,"软化程度");
                materialEditor.ShaderProperty(DissolveWidth,"溶解边缘宽度");
                materialEditor.ShaderProperty(DissolveEdgeColor,"溶解边缘颜色");
                EditorGUI.indentLevel--;
            }
            EditorGUILayout.Space(10);
        }
        EditorGUILayout.EndVertical();
        
        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        Distoration_Foldout = Foldout(Distoration_Foldout, "扰动");
        if (Distoration_Foldout)
        {
            GUILayout.Label("扰动", EditorStyles.boldLabel);
            EditorGUI.indentLevel++;
            materialEditor.ShaderProperty(EnableDistortion_prop,"启用扰动");
            
            bool EnableDistortion = EnableDistortion_prop.floatValue != 0;
            if (EnableDistortion)
            {
                EditorGUILayout.Space(5);
                EditorGUI.indentLevel++;
                materialEditor.ShaderProperty(EnableMainTexDistortion_prop,"启用主贴图扰动");
                materialEditor.ShaderProperty(EnableDissolveMaskDistortion_prop,"启用溶解遮罩扰动");
                EditorGUILayout.Space(5);
                materialEditor.TexturePropertySingleLine(new GUIContent("扰动图"), DistortionMap);
                materialEditor.TextureScaleOffsetProperty(DistortionMap);
                EditorGUILayout.Space(5);
                materialEditor.ShaderProperty(EnableDistortionPolarCoordinates_prop,"启用极坐标");
                bool EnablePolarCoordinates = EnableDistortionPolarCoordinates_prop.floatValue != 0;
                if (!EnablePolarCoordinates)
                {
                    materialEditor.ShaderProperty(USpeed_Distortion,"U Speed");
                    materialEditor.ShaderProperty(VSpeed_Distortion,"V Speed");
                }
                else
                {
                    materialEditor.ShaderProperty(PolarCoordinatesMovingSpeed_Distoration, "Speed");
                }
                EditorGUILayout.Space(5);
                materialEditor.ShaderProperty(EnableDistortionMapRotation_prop,"启用扰动贴图旋转");
                bool EnableDistortionMapRotation = EnableDistortionMapRotation_prop.floatValue != 0;
                if (EnableDistortionMapRotation)
                {
                    materialEditor.ShaderProperty(DistortionMapRotation,"扰动贴图旋转");
                }
                
                materialEditor.ShaderProperty(DistortionIntensity,"扰动强度");
                EditorGUI.indentLevel--;  
            }
            EditorGUI.indentLevel--;
            EditorGUILayout.Space(10);
        }
        EditorGUILayout.EndVertical();
        
        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        Mode_Foldout = Foldout(Mode_Foldout, "模式");
        if (Mode_Foldout)
        {
            GUILayout.Label("混合模式", EditorStyles.boldLabel);
            EditorGUI.indentLevel++;
            materialEditor.ShaderProperty(BlendSrc,"Blend Src Factor");
            materialEditor.ShaderProperty(BlendDst,"Blend Dst Factor");
            EditorGUI.indentLevel--;
        
            EditorGUILayout.Space(10);
        
            GUILayout.Label("剔除模式", EditorStyles.boldLabel);
            EditorGUI.indentLevel++;
            materialEditor.ShaderProperty(CullMode, "Cull Mode");
            EditorGUI.indentLevel--;
            
            EditorGUILayout.Space(10);
        }
        EditorGUILayout.EndVertical();
        
        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        Other_Foldout = Foldout(Other_Foldout, "其它");
        if (Other_Foldout)
        {
            // 渲染默认 GUI
            base.OnGUI(materialEditor, properties);
            EditorGUILayout.Space(10);
        }
        EditorGUILayout.EndVertical();
        
        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        Instructions_Foldout = Foldout(Instructions_Foldout, "说明");
        if (Instructions_Foldout)
        {
            EditorGUI.indentLevel++;
            EditorGUILayout.LabelField("粒子系统中请先在Render中添加UV2，再添加 Custom1 以正确启用自定义数据");
            EditorGUI.indentLevel++;
        }
        EditorGUILayout.EndVertical();
        
        EditorGUI.EndChangeCheck();
    }
    
    
}