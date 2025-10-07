using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
using UnityEngine.Experimental.Rendering;

namespace UnityEditor.Rendering.Universal
{
    internal class CustomTerrainGrassShaderGUI : UnityEditor.ShaderGUI, ITerrainLayerCustomUI
    {
        private class StylesLayer
        {
            public readonly GUIContent warningHeightBasedBlending = new GUIContent("Height-based blending is disabled if you have more than four TerrainLayer materials!");

            public readonly GUIContent enableHeightBlend = new GUIContent("Enable Height-based Blend", "Blend terrain layers based on height values.");
            public readonly GUIContent heightTransition = new GUIContent("Height Transition", "Size in world units of the smooth transition between layers.");
            public readonly GUIContent enableInstancedPerPixelNormal = new GUIContent("Enable Per-pixel Normal", "Enable per-pixel normal when the terrain uses instanced rendering.");

            public readonly GUIContent diffuseTexture = new GUIContent("Diffuse");
            public readonly GUIContent colorTint = new GUIContent("Color Tint");
            public readonly GUIContent opacityAsDensity = new GUIContent("Opacity as Density", "Enable Density Blend (if unchecked, opacity is used as Smoothness)");
            public readonly GUIContent normalMapTexture = new GUIContent("Normal Map");
            public readonly GUIContent normalScale = new GUIContent("Normal Scale");
            public readonly GUIContent maskMapTexture = new GUIContent("Mask", "R: Metallic\nG: AO\nB: Height\nA: Smoothness");
            public readonly GUIContent maskMapTextureWithoutHeight = new GUIContent("Mask Map", "R: Metallic\nG: AO\nA: Smoothness");
            public readonly GUIContent channelRemapping = new GUIContent("Channel Remapping");
            public readonly GUIContent defaultValues = new GUIContent("Channel Default Values");
            public readonly GUIContent metallic = new GUIContent("R: Metallic");
            public readonly GUIContent ao = new GUIContent("G: AO");
            public readonly GUIContent height = new GUIContent("B: Height");
            public readonly GUIContent heightParametrization = new GUIContent("Parametrization");
            public readonly GUIContent heightAmplitude = new GUIContent("Amplitude (cm)");
            public readonly GUIContent heightBase = new GUIContent("Base (cm)");
            public readonly GUIContent heightMin = new GUIContent("Min (cm)");
            public readonly GUIContent heightMax = new GUIContent("Max (cm)");
            public readonly GUIContent heightCm = new GUIContent("B: Height (cm)");
            public readonly GUIContent smoothness = new GUIContent("A: Smoothness");
        }

        static StylesLayer s_Styles = null;
        private static StylesLayer styles { get { if (s_Styles == null) s_Styles = new StylesLayer(); return s_Styles; } }

        public CustomTerrainGrassShaderGUI()
        {
            
        }

        // Height blend params
        MaterialProperty enableHeightBlend = null;
        const string kEnableHeightBlend = "_EnableHeightBlend";

        MaterialProperty heightTransition = null;
        const string kHeightTransition = "_HeightTransition";

        // Per-pixel Normal (while instancing)
        MaterialProperty enableInstancedPerPixelNormal = null;
        const string kEnableInstancedPerPixelNormal = "_EnableInstancedPerPixelNormal";

        private bool m_ShowChannelRemapping = false;
        enum HeightParametrization
        {
            Amplitude,
            MinMax
        };
        private HeightParametrization m_HeightParametrization = HeightParametrization.Amplitude;

        private static bool DoesTerrainUseMaskMaps(TerrainLayer[] terrainLayers)
        {
            for (int i = 0; i < terrainLayers.Length; ++i)
            {
                if (terrainLayers[i].maskMapTexture != null)
                    return true;
            }
            return false;
        }

        protected void FindMaterialProperties(MaterialProperty[] props)
        {
            enableHeightBlend = FindProperty(kEnableHeightBlend, props, false);
            heightTransition = FindProperty(kHeightTransition, props, false);
            enableInstancedPerPixelNormal = FindProperty(kEnableInstancedPerPixelNormal, props, false);
        }

        static public void SetupMaterialKeywords(Material material)
        {
            bool enableHeightBlend = (material.HasProperty(kEnableHeightBlend) && material.GetFloat(kEnableHeightBlend) > 0);
            CoreUtils.SetKeyword(material, "_TERRAIN_BLEND_HEIGHT", enableHeightBlend);

            bool enableInstancedPerPixelNormal = material.GetFloat(kEnableInstancedPerPixelNormal) > 0.0f;
            CoreUtils.SetKeyword(material, "_TERRAIN_INSTANCED_PERPIXEL_NORMAL", enableInstancedPerPixelNormal);
        }

        static public bool TextureHasAlpha(Texture2D inTex)
        {
            if (inTex != null)
            {
                return GraphicsFormatUtility.HasAlphaChannel(GraphicsFormatUtility.GetGraphicsFormat(inTex.format, true));
            }
            return false;
        }

        private bool showGrassLayer1Presets;
        private bool showGrassLayer2Presets;
        private bool showGrassLayer3Presets;
        private bool showGrassLayer4Presets;
        private bool showWindSettings;
        private bool showRandomPresets;
        private bool showForwardPresets;
        private bool showInteractiveSettings;
        private bool showShodowSettings;
        private bool showOtherSettings;
        private bool showSettings;
        
        public override void OnGUI(MaterialEditor materialEditorIn, MaterialProperty[] properties)
        {
            //刷草参数设置
            EditorGUI.BeginChangeCheck();
            
            FindMaterialProperties(properties);
            
            GUIContent Lerp = new GUIContent("Terrain Fusion");
            MaterialProperty _Lerp = FindProperty("_Lerp", properties);
            materialEditorIn.ShaderProperty(_Lerp,Lerp);
            
            EditorGUILayout.Space(10);
            
            //图层1
            showGrassLayer1Presets = EditorGUILayout.Foldout(showGrassLayer1Presets, "Grass Layer 1", true);
            if (showGrassLayer1Presets)
            {
                EditorGUI.indentLevel++;
                //【开关】
                GUIContent EnableGrass1 = new GUIContent("Enable Grass");
                //【开关索引】
                MaterialProperty _EnableGrass1 = FindProperty("_EnableGrass1", properties);
                //【开关赋值】
                materialEditorIn.ShaderProperty(_EnableGrass1,EnableGrass1);
                
                EditorGUILayout.Space(5);

                //Color
                GUIContent GrassColorTint1 = new GUIContent("Grass Color Tint");
                MaterialProperty _GrassColorTint1 = FindProperty("_GrassColorTint1", properties);
                materialEditorIn.ShaderProperty(_GrassColorTint1,GrassColorTint1);
                GUIContent TopColor1 = new GUIContent("Top Color");
                MaterialProperty _TopColor1 = FindProperty("_TopColor1", properties);
                materialEditorIn.ShaderProperty(_TopColor1,TopColor1);
                GUIContent BottomColor1 = new GUIContent("Bottom Color");
                MaterialProperty _BottomColor1 = FindProperty("_BottomColor1", properties);
                materialEditorIn.ShaderProperty(_BottomColor1,BottomColor1);
                
                EditorGUILayout.Space(5);
                
                //Height&Width
                GUIContent BaldeHeight1 = new GUIContent("Balde Height");
                MaterialProperty _BladeHeight1 = FindProperty("_BladeHeight1", properties);
                materialEditorIn.ShaderProperty(_BladeHeight1,BaldeHeight1);
                
                GUIContent BaldeWidth1 = new GUIContent("Balde Width");
                MaterialProperty _BladeWidth1 = FindProperty("_BladeWidth1", properties);
                materialEditorIn.ShaderProperty(_BladeWidth1,BaldeWidth1);
                
                EditorGUILayout.Space(5);
                
                //Density
                GUIContent GrassDensity1 = new GUIContent("Grass Density");
                MaterialProperty _GrassDensity1 = FindProperty("_GrassDensity1", properties);
                materialEditorIn.ShaderProperty(_GrassDensity1,GrassDensity1);

                EditorGUI.indentLevel--;

            }
            
            EditorGUILayout.Space(10);
            
            //图层2
            showGrassLayer2Presets = EditorGUILayout.Foldout(showGrassLayer2Presets, "Grass Layer 2", true);
            if (showGrassLayer2Presets)
            {
                EditorGUI.indentLevel++;
                
                //【开关】
                GUIContent EnableGrass2 = new GUIContent("Enable Grass");
                //【开关索引】
                MaterialProperty _EnableGrass2 = FindProperty("_EnableGrass2", properties);
                //【开关赋值】
                materialEditorIn.ShaderProperty(_EnableGrass2,EnableGrass2);
                
                EditorGUILayout.Space(5);
                
                //Color
                GUIContent GrassColorTint2 = new GUIContent("Grass Color Tint");
                MaterialProperty _GrassColorTint2 = FindProperty("_GrassColorTint2", properties);
                materialEditorIn.ShaderProperty(_GrassColorTint2,GrassColorTint2);
                GUIContent TopColor2 = new GUIContent("Top Color");
                MaterialProperty _TopColor2 = FindProperty("_TopColor2", properties);
                materialEditorIn.ShaderProperty(_TopColor2,TopColor2);
                GUIContent BottomColor2 = new GUIContent("Bottom Color");
                MaterialProperty _BottomColor2 = FindProperty("_BottomColor2", properties);
                materialEditorIn.ShaderProperty(_BottomColor2,BottomColor2);
                
                EditorGUILayout.Space(5);
                
                //Height&Width
                GUIContent BaldeHeight2 = new GUIContent("Balde Height");
                MaterialProperty _BladeHeight2 = FindProperty("_BladeHeight2", properties);
                materialEditorIn.ShaderProperty(_BladeHeight2,BaldeHeight2);
                
                GUIContent BaldeWidth2 = new GUIContent("Balde Width");
                MaterialProperty _BladeWidth2 = FindProperty("_BladeWidth2", properties);
                materialEditorIn.ShaderProperty(_BladeWidth2,BaldeWidth2);
                
                EditorGUILayout.Space(5);
                
                //Density
                GUIContent GrassDensity2 = new GUIContent("Grass Density");
                MaterialProperty _GrassDensity2 = FindProperty("_GrassDensity2", properties);
                materialEditorIn.ShaderProperty(_GrassDensity2,GrassDensity2);
                
                EditorGUI.indentLevel--;
            }
            
            EditorGUILayout.Space(10);
            
            //图层3
            showGrassLayer3Presets = EditorGUILayout.Foldout(showGrassLayer3Presets, "Grass Layer 3", true);
            if (showGrassLayer3Presets)
            {
                
                EditorGUI.indentLevel++;
                
                //【开关】
                GUIContent EnableGrass3 = new GUIContent("Enable Grass");
                //【开关索引】
                MaterialProperty _EnableGrass3 = FindProperty("_EnableGrass3", properties);
                //【开关赋值】
                materialEditorIn.ShaderProperty(_EnableGrass3,EnableGrass3);
                
                EditorGUILayout.Space(5);
                
                //Color
                GUIContent GrassColorTint3 = new GUIContent("Grass Color Tint");
                MaterialProperty _GrassColorTint3 = FindProperty("_GrassColorTint3", properties);
                materialEditorIn.ShaderProperty(_GrassColorTint3,GrassColorTint3);
                GUIContent TopColor3 = new GUIContent("Top Color");
                MaterialProperty _TopColor3 = FindProperty("_TopColor3", properties);
                materialEditorIn.ShaderProperty(_TopColor3,TopColor3);
                GUIContent BottomColor3 = new GUIContent("Bottom Color");
                MaterialProperty _BottomColor3 = FindProperty("_BottomColor3", properties);
                materialEditorIn.ShaderProperty(_BottomColor3,BottomColor3);
                
                EditorGUILayout.Space(5);
                
                //Height&Width
                GUIContent BaldeHeight3 = new GUIContent("Balde Height");
                MaterialProperty _BladeHeight3 = FindProperty("_BladeHeight3", properties);
                materialEditorIn.ShaderProperty(_BladeHeight3,BaldeHeight3);
                
                GUIContent BaldeWidth3 = new GUIContent("Balde Width");
                MaterialProperty _BladeWidth3 = FindProperty("_BladeWidth3", properties);
                materialEditorIn.ShaderProperty(_BladeWidth3,BaldeWidth3);
                
                EditorGUILayout.Space(5);
                
                //Density
                GUIContent GrassDensity3 = new GUIContent("Grass Density");
                MaterialProperty _GrassDensity3 = FindProperty("_GrassDensity3", properties);
                materialEditorIn.ShaderProperty(_GrassDensity3,GrassDensity3);
                
                EditorGUI.indentLevel--;
                
            }
            
            EditorGUILayout.Space(10);
            
            //图层4
            showGrassLayer4Presets = EditorGUILayout.Foldout(showGrassLayer4Presets, "Grass Layer 4", true);
            if (showGrassLayer4Presets)
            {
                
                EditorGUI.indentLevel++;
                
                //【开关】
                GUIContent EnableGrass4 = new GUIContent("Enable Grass");
                //【开关索引】
                MaterialProperty _EnableGrass4 = FindProperty("_EnableGrass4", properties);
                //【开关赋值】
                materialEditorIn.ShaderProperty(_EnableGrass4,EnableGrass4);
                
                EditorGUILayout.Space(5);
                
                //Color
                GUIContent GrassColorTint4 = new GUIContent("Grass Color Tint");
                MaterialProperty _GrassColorTint4 = FindProperty("_GrassColorTint4", properties);
                materialEditorIn.ShaderProperty(_GrassColorTint4,GrassColorTint4);
                GUIContent TopColor4 = new GUIContent("Top Color");
                MaterialProperty _TopColor4 = FindProperty("_TopColor4", properties);
                materialEditorIn.ShaderProperty(_TopColor4,TopColor4);
                GUIContent BottomColor4 = new GUIContent("Bottom Color");
                MaterialProperty _BottomColor4 = FindProperty("_BottomColor4", properties);
                materialEditorIn.ShaderProperty(_BottomColor4,BottomColor4);
                
                EditorGUILayout.Space(5);
                
                //Height&Width
                GUIContent BaldeHeight4 = new GUIContent("Balde Height");
                MaterialProperty _BladeHeight4 = FindProperty("_BladeHeight4", properties);
                materialEditorIn.ShaderProperty(_BladeHeight4,BaldeHeight4);
                
                GUIContent BaldeWidth4 = new GUIContent("Balde Width");
                MaterialProperty _BladeWidth4 = FindProperty("_BladeWidth4", properties);
                materialEditorIn.ShaderProperty(_BladeWidth4,BaldeWidth4);
                
                EditorGUILayout.Space(5);
                
                //Density
                GUIContent GrassDensity4 = new GUIContent("Grass Density");
                MaterialProperty _GrassDensity4 = FindProperty("_GrassDensity4", properties);
                materialEditorIn.ShaderProperty(_GrassDensity4,GrassDensity4);
                
                EditorGUI.indentLevel--;
            }
            
            EditorGUILayout.Space(10);
            
            showSettings = EditorGUILayout.Foldout(showSettings, "Settings", true);
            if (showSettings)
            {
                EditorGUI.indentLevel++;
                showWindSettings = EditorGUILayout.Foldout(showWindSettings, "Wind Settings", true);
                if (showWindSettings)
                {
                    EditorGUI.indentLevel++;
                    GUIContent WindDistortionMap = new GUIContent("Wind Distortion Map");
                    MaterialProperty _WindDistortionMap = FindProperty("_WindDistortionMap", properties);
                    materialEditorIn.TexturePropertySingleLine(WindDistortionMap, _WindDistortionMap);
                    
                    EditorGUILayout.Space(5);

                    GUIContent WindFrequency = new GUIContent("Wind Frequency");
                    MaterialProperty _WindFrequency = FindProperty("_WindFrequency", properties);
                    materialEditorIn.ShaderProperty(_WindFrequency,WindFrequency);

                    GUIContent WindStrength = new GUIContent("Wind Strength");
                    MaterialProperty _WindStrength = FindProperty("_WindStrength", properties);
                    materialEditorIn.ShaderProperty(_WindStrength,WindStrength);
                    EditorGUI.indentLevel--;
                }
                
                EditorGUILayout.Space(10);

                showRandomPresets = EditorGUILayout.Foldout(showRandomPresets, "Random Settings", true);
                if (showRandomPresets)
                {
                    EditorGUI.indentLevel++;
                    GUIContent BladeHeightRandom = new GUIContent("Balde Height Random");
                    GUIContent BladeWidthRandom = new GUIContent("Balde Width Random");
                    MaterialProperty _BladeHeightRandom = FindProperty("_BladeHeightRandom", properties);
                    MaterialProperty _BladeWidthRandom = FindProperty("_BladeWidthRandom", properties);
                    materialEditorIn.ShaderProperty(_BladeHeightRandom,BladeHeightRandom);
                    materialEditorIn.ShaderProperty(_BladeWidthRandom,BladeWidthRandom);
                    
                    EditorGUILayout.Space(5);
                    
                    GUIContent BendRotationRandom = new GUIContent("Bend Rotation Random");
                    MaterialProperty _BendRotationRandom = FindProperty("_BendRotationRandom", properties);
                    materialEditorIn.ShaderProperty(_BendRotationRandom,BendRotationRandom);
                    
                    EditorGUILayout.Space(5);
                    
                    GUIContent ColorRandom = new GUIContent("Color Random");
                    MaterialProperty _ColorRandom = FindProperty("_ColorRandom", properties);
                    materialEditorIn.ShaderProperty(_ColorRandom,ColorRandom);

                    EditorGUI.indentLevel--;
                }
                EditorGUI.EndChangeCheck();
                
                EditorGUILayout.Space(10);

                showForwardPresets = EditorGUILayout.Foldout(showForwardPresets, "Forward Seetings", true);
                if (showForwardPresets)
                {
                    EditorGUI.indentLevel++;
                    
                    GUIContent BladeForward = new GUIContent("Blade Forward");
                    MaterialProperty _BladeForward = FindProperty("_BladeForward", properties);
                    materialEditorIn.ShaderProperty(_BladeForward,BladeForward);

                    GUIContent BladeCurve = new GUIContent("Blade Curve");
                    MaterialProperty _BladeCurve = FindProperty("_BladeCurve", properties);
                    materialEditorIn.ShaderProperty(_BladeCurve,BladeCurve);
                    
                    EditorGUI.indentLevel--;
                }

                EditorGUILayout.Space(10);
                
                showInteractiveSettings =
                    EditorGUILayout.Foldout(showInteractiveSettings, "Interactive Settings", true);
                if (showInteractiveSettings)
                {
                    EditorGUI.indentLevel++;
                    GUIContent PushRadius = new GUIContent("Push Radius");
                    MaterialProperty _PushRadius = FindProperty("_PushRadius", properties);
                    materialEditorIn.ShaderProperty(_PushRadius,PushRadius);
                    
                    GUIContent Strength = new GUIContent("Strength");
                    MaterialProperty _Strength = FindProperty("_Strength", properties);
                    materialEditorIn.ShaderProperty(_Strength,Strength);
                    EditorGUI.indentLevel--;
                }
                
                EditorGUILayout.Space(10);
                
                showShodowSettings = EditorGUILayout.Foldout(showShodowSettings, "Shadow Settings", true);
                if (showShodowSettings)
                {
                    EditorGUI.indentLevel++;
                    
                    GUIContent TranslucentGain = new GUIContent("Translucent Gain");
                    MaterialProperty _TranslucentGain = FindProperty("_TranslucentGain", properties);
                    materialEditorIn.ShaderProperty(_TranslucentGain,TranslucentGain);
                    
                    EditorGUI.indentLevel--;
                }
                EditorGUILayout.Space(10);
                
                showOtherSettings = EditorGUILayout.Foldout(showOtherSettings, "Other Settings", true);
                if (showOtherSettings)
                {
                    bool optionsChanged = false;
                    EditorGUI.BeginChangeCheck();
                    {
                        if (enableHeightBlend != null)
                        {
                            EditorGUI.indentLevel++;
                            materialEditorIn.ShaderProperty(enableHeightBlend, styles.enableHeightBlend);
                            if (enableHeightBlend.floatValue > 0)
                            {
                                EditorGUI.indentLevel++;
                                EditorGUILayout.HelpBox(styles.warningHeightBasedBlending.text, MessageType.Info);
                                materialEditorIn.ShaderProperty(heightTransition, styles.heightTransition);
                                EditorGUI.indentLevel--;
                            }
                            EditorGUI.indentLevel--;
                        }

                        EditorGUILayout.Space();
                    }
                    if (EditorGUI.EndChangeCheck())
                    {
                        optionsChanged = true;
                    }

                    bool enablePerPixelNormalChanged = false;

                    // Since Instanced Per-pixel normal is actually dependent on instancing enabled or not, it is not
                    // important to check it in the GUI.  The shader will make sure it is enabled/disabled properly.s
                    if (enableInstancedPerPixelNormal != null)
                    {
                        EditorGUI.indentLevel++;
                        EditorGUI.BeginChangeCheck();
                        materialEditorIn.ShaderProperty(enableInstancedPerPixelNormal, styles.enableInstancedPerPixelNormal);
                        enablePerPixelNormalChanged = EditorGUI.EndChangeCheck();
                        EditorGUI.indentLevel--;
                    }

                    if (optionsChanged || enablePerPixelNormalChanged)
                    {
                        foreach (var obj in materialEditorIn.targets)
                        {
                            SetupMaterialKeywords((Material)obj);
                        }
                    }
                }
                EditorGUI.indentLevel--;
            }
            
            EditorGUILayout.Space(10);
            
            //默认UI
            //materialEditorIn.PropertiesDefaultGUI(properties);
            
            // We should always do this call at the end
            materialEditorIn.serializedObject.ApplyModifiedProperties();
        }

        bool ITerrainLayerCustomUI.OnTerrainLayerGUI(TerrainLayer terrainLayer, Terrain terrain)
        {
            var terrainLayers = terrain.terrainData.terrainLayers;

            // Don't use the member field enableHeightBlend as ShaderGUI.OnGUI might not be called if the material UI is folded.
            // heightblend shouldn't be available if we are in multi-pass mode, because it is guaranteed to be broken.
            bool heightBlendAvailable = (terrainLayers.Length <= 4);
            bool heightBlend = heightBlendAvailable && terrain.materialTemplate.HasProperty(kEnableHeightBlend) && (terrain.materialTemplate.GetFloat(kEnableHeightBlend) > 0);

            terrainLayer.diffuseTexture = EditorGUILayout.ObjectField(styles.diffuseTexture, terrainLayer.diffuseTexture, typeof(Texture2D), false) as Texture2D;
            TerrainLayerUtility.ValidateDiffuseTextureUI(terrainLayer.diffuseTexture);

            var diffuseRemapMin = terrainLayer.diffuseRemapMin;
            var diffuseRemapMax = terrainLayer.diffuseRemapMax;
            EditorGUI.BeginChangeCheck();

            bool enableDensity = false;
            if (terrainLayer.diffuseTexture != null)
            {
                var rect = GUILayoutUtility.GetLastRect();
                rect.y += 16 + 4;
                rect.width = EditorGUIUtility.labelWidth + 64;
                rect.height = 16;

                ++EditorGUI.indentLevel;

                var diffuseTint = new Color(diffuseRemapMax.x, diffuseRemapMax.y, diffuseRemapMax.z);
                diffuseTint = EditorGUI.ColorField(rect, styles.colorTint, diffuseTint, true, false, false);
                diffuseRemapMax.x = diffuseTint.r;
                diffuseRemapMax.y = diffuseTint.g;
                diffuseRemapMax.z = diffuseTint.b;
                diffuseRemapMin.x = diffuseRemapMin.y = diffuseRemapMin.z = 0;

                if (!heightBlend)
                {
                    rect.y = rect.yMax + 2;
                    enableDensity = EditorGUI.Toggle(rect, styles.opacityAsDensity, diffuseRemapMin.w > 0);
                }

                --EditorGUI.indentLevel;
            }
            diffuseRemapMax.w = 1;
            diffuseRemapMin.w = enableDensity ? 1 : 0;

            if (EditorGUI.EndChangeCheck())
            {
                terrainLayer.diffuseRemapMin = diffuseRemapMin;
                terrainLayer.diffuseRemapMax = diffuseRemapMax;
            }

            // Display normal map UI
            terrainLayer.normalMapTexture = EditorGUILayout.ObjectField(styles.normalMapTexture, terrainLayer.normalMapTexture, typeof(Texture2D), false) as Texture2D;
            TerrainLayerUtility.ValidateNormalMapTextureUI(terrainLayer.normalMapTexture, TerrainLayerUtility.CheckNormalMapTextureType(terrainLayer.normalMapTexture));

            if (terrainLayer.normalMapTexture != null)
            {
                var rect = GUILayoutUtility.GetLastRect();
                rect.y += 16 + 4;
                rect.width = EditorGUIUtility.labelWidth + 64;
                rect.height = 16;

                ++EditorGUI.indentLevel;
                terrainLayer.normalScale = EditorGUI.FloatField(rect, styles.normalScale, terrainLayer.normalScale);
                --EditorGUI.indentLevel;
            }

            // Display the mask map UI and the remap controls
            terrainLayer.maskMapTexture = EditorGUILayout.ObjectField(heightBlend ? styles.maskMapTexture : styles.maskMapTextureWithoutHeight, terrainLayer.maskMapTexture, typeof(Texture2D), false) as Texture2D;
            TerrainLayerUtility.ValidateMaskMapTextureUI(terrainLayer.maskMapTexture);

            var maskMapRemapMin = terrainLayer.maskMapRemapMin;
            var maskMapRemapMax = terrainLayer.maskMapRemapMax;
            var smoothness = terrainLayer.smoothness;
            var metallic = terrainLayer.metallic;

            ++EditorGUI.indentLevel;
            EditorGUI.BeginChangeCheck();

            m_ShowChannelRemapping = EditorGUILayout.Foldout(m_ShowChannelRemapping, terrainLayer.maskMapTexture != null ? s_Styles.channelRemapping : s_Styles.defaultValues);

            if (m_ShowChannelRemapping)
            {
                if (terrainLayer.maskMapTexture != null)
                {
                    float min, max;
                    min = maskMapRemapMin.x; max = maskMapRemapMax.x;
                    EditorGUILayout.MinMaxSlider(s_Styles.metallic, ref min, ref max, 0, 1);
                    maskMapRemapMin.x = min; maskMapRemapMax.x = max;

                    min = maskMapRemapMin.y; max = maskMapRemapMax.y;
                    EditorGUILayout.MinMaxSlider(s_Styles.ao, ref min, ref max, 0, 1);
                    maskMapRemapMin.y = min; maskMapRemapMax.y = max;

                    if (heightBlend)
                    {
                        EditorGUILayout.LabelField(styles.height);
                        ++EditorGUI.indentLevel;
                        m_HeightParametrization = (HeightParametrization)EditorGUILayout.EnumPopup(styles.heightParametrization, m_HeightParametrization);
                        if (m_HeightParametrization == HeightParametrization.Amplitude)
                        {
                            // (height - heightBase) * amplitude
                            float amplitude = Mathf.Max(maskMapRemapMax.z - maskMapRemapMin.z, Mathf.Epsilon); // to avoid divide by zero
                            float heightBase = maskMapRemapMin.z / amplitude;
                            amplitude = EditorGUILayout.FloatField(styles.heightAmplitude, amplitude * 100) / 100;
                            heightBase = EditorGUILayout.FloatField(styles.heightBase, heightBase * 100) / 100;
                            maskMapRemapMin.z = heightBase * amplitude;
                            maskMapRemapMax.z = (1.0f - heightBase) * amplitude;
                        }
                        else
                        {
                            maskMapRemapMin.z = EditorGUILayout.FloatField(styles.heightMin, maskMapRemapMin.z * 100) / 100;
                            maskMapRemapMax.z = EditorGUILayout.FloatField(styles.heightMax, maskMapRemapMax.z * 100) / 100;
                        }
                        --EditorGUI.indentLevel;
                    }

                    min = maskMapRemapMin.w; max = maskMapRemapMax.w;
                    EditorGUILayout.MinMaxSlider(s_Styles.smoothness, ref min, ref max, 0, 1);
                    maskMapRemapMin.w = min; maskMapRemapMax.w = max;
                }
                else
                {
                    metallic = EditorGUILayout.Slider(s_Styles.metallic, metallic, 0, 1);
                    // AO and Height are still exclusively controlled via the maskRemap controls
                    // metallic and smoothness have their own values as fields within the LayerData.
                    maskMapRemapMax.y = EditorGUILayout.Slider(s_Styles.ao, maskMapRemapMax.y, 0, 1);
                    if (heightBlend)
                    {
                        maskMapRemapMax.z = EditorGUILayout.FloatField(s_Styles.heightCm, maskMapRemapMax.z * 100) / 100;
                    }

                    // There's a possibility that someone could slide max below the existing min value
                    // so we'll just protect against that by locking the min value down a little bit.
                    // In the case of height (Z), we are trying to set min to no lower than zero value unless
                    // max goes negative.  Zero is a good sensible value for the minimum.  For AO (Y), we
                    // don't need this extra protection step because the UI blocks us from going negative
                    // anyway.  In both cases, pushing the slider below the min value will lock them together,
                    // but min will be "left behind" if you go back up.
                    maskMapRemapMin.y = Mathf.Min(maskMapRemapMin.y, maskMapRemapMax.y);
                    maskMapRemapMin.z = Mathf.Min(Mathf.Max(0, maskMapRemapMin.z), maskMapRemapMax.z);

                    if (TextureHasAlpha(terrainLayer.diffuseTexture))
                    {
                        GUIStyle warnStyle = new GUIStyle(GUI.skin.label);
                        warnStyle.wordWrap = true;
                        GUILayout.Label("Smoothness is controlled by diffuse alpha channel", warnStyle);
                    }
                    else
                        smoothness = EditorGUILayout.Slider(s_Styles.smoothness, smoothness, 0, 1);
                }
            }

            if (EditorGUI.EndChangeCheck())
            {
                terrainLayer.maskMapRemapMin = maskMapRemapMin;
                terrainLayer.maskMapRemapMax = maskMapRemapMax;
                terrainLayer.smoothness = smoothness;
                terrainLayer.metallic = metallic;
            }
            --EditorGUI.indentLevel;

            EditorGUILayout.Space();
            TerrainLayerUtility.TilingSettingsUI(terrainLayer);

            return true;
        }
    }
}
