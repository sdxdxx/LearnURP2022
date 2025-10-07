Shader "URP/Terrain/CustomTerrianGrass"
{
    Properties
    {
	    //Grass
	    [HideInInspector][Toggle(_Grass1)]_EnableGrass1("EnableGrass1",Float) = 0.0
    	[HideInInspector][Toggle(_Grass2)]_EnableGrass2("EnableGrass2",Float) = 0.0
    	[HideInInspector][Toggle(_Grass3)]_EnableGrass3("EnableGrass3",Float) = 0.0
    	[HideInInspector][Toggle(_Grass4)]_EnableGrass4("EnableGrass4",Float) = 0.0
	    
        [HideInInspector]_Lerp("Terrain Fusion",Range(0,1)) = 0
	    
    	//GrassColor1
        [HideInInspector]_GrassColorTint1("Grass Color Tint",Color) = (1.0,1.0,1.0,1.0)
        [HideInInspector]_TopColor1("TopColor",Color) = (0.1,1.0,0.1,1.0)
        [HideInInspector]_BottomColor1("BottomColor",Color) = (0,0.5,0,1.0)
	    
    	//GrassColor2
        [HideInInspector]_GrassColorTint2("Grass Color Tint",Color) = (1.0,1.0,1.0,1.0)
        [HideInInspector]_TopColor2("TopColor",Color) = (0.1,1.0,0.1,1.0)
        [HideInInspector]_BottomColor2("BottomColor",Color) = (0,0.5,0,1.0)
	    
    	//GrassColor3
        [HideInInspector]_GrassColorTint3("Grass Color Tint",Color) = (1.0,1.0,1.0,1.0)
        [HideInInspector]_TopColor3("TopColor",Color) = (0.1,1.0,0.1,1.0)
        [HideInInspector]_BottomColor3("BottomColor",Color) = (0,0.5,0,1.0)
	    
    	//GrassColor4
        [HideInInspector]_GrassColorTint4("Grass Color Tint",Color) = (1.0,1.0,1.0,1.0)
        [HideInInspector]_TopColor4("TopColor",Color) = (0.1,1.0,0.1,1.0)
        [HideInInspector] _BottomColor4("BottomColor",Color) = (0,0.5,0,1.0)
    	
    	[HideInInspector]_ColorRandom("ColorRandom",Range(0,0.2)) = 0
        
        //HeightRandom
        [HideInInspector]_BladeHeightRandom("Blade Height Random", Float) = 0.3
    	
    	//WidthRandom
	    [HideInInspector]_BladeWidthRandom("Blade Width Random", Float) = 0.02
    	
    	//Height And Width 1
    	[HideInInspector]_BladeHeight1("Blade Height 1", Float) = 0.5
        [HideInInspector]_BladeWidth1("Blade Width 1", Float) = 0.05
    	
    	//Height And Width 2
    	[HideInInspector]_BladeHeight2("Blade Height 2", Float) = 0.5
        [HideInInspector]_BladeWidth2("Blade Width 2", Float) = 0.05
    	
    	//Height And Width 3
    	[HideInInspector]_BladeHeight3("Blade Height 3", Float) = 0.5
        [HideInInspector]_BladeWidth3("Blade Width 3", Float) = 0.05
    	
    	//Height And Width 4
    	[HideInInspector]_BladeHeight4("Blade Height 4", Float) = 0.5
        [HideInInspector]_BladeWidth4("Blade Width 4", Float) = 0.05
    	
    	
	    //Forward
    	[HideInInspector]_BladeForward("Blade Forward Amount", Float) = 0.38
		[HideInInspector]_BladeCurve("Blade Curvature Amount", Range(1, 4)) = 2
        
        //Bend
        [HideInInspector]_BendRotationRandom("Bend Rotation Random", Range(0, 1)) = 0.2
        
    	//Wind
    	[HideInInspector]_WindDistortionMap("Wind Distortion Map", 2D) = "white" {}
        [HideInInspector]_WindFrequency("Wind Frequency", Vector) = (0.05, 0.05, 0, 0)
    	[HideInInspector]_WindStrength("Wind Strength", Range(0,10)) = 1
    	
    	//Density
    	[HideInInspector][IntRange]_GrassDensity1("Grass Density",Range(1,20)) = 8
    	[HideInInspector][IntRange]_GrassDensity2("Grass Density",Range(1,20)) = 8
    	[HideInInspector][IntRange]_GrassDensity3("Grass Density",Range(1,20)) = 8
    	[HideInInspector][IntRange]_GrassDensity4("Grass Density",Range(1,20)) = 8
    	
    	//Gain
    	[HideInInspector]_TranslucentGain("Translucent Gain",Range(0,0.5)) = 0.3
    	
	    //Interactive Grass
	    [HideInInspector]_PushRadius("Push Radius",float) = 0
    	[HideInInspector]_Strength("Strength",Range(0,5)) = 0
    	
    	//-----------------------------------------------------------------------------------
        
        
    	//Others
        [HideInInspector]_HeightTransition("Height Transition", Range(0, 1.0)) = 0.0
    	[HideInInspector] [ToggleUI] _EnableHeightBlend("EnableHeightBlend", Float) = 0.0
        
    	
        [HideInInspector] [PerRendererData] _NumLayersCount ("Total Layer Count", Float) = 1.0

        // set by terrain engine
        [HideInInspector] _Control("Control (RGBA)", 2D) = "red" {}
        [HideInInspector] _Splat3("Layer 3 (A)", 2D) = "grey" {}
        [HideInInspector] _Splat2("Layer 2 (B)", 2D) = "grey" {}
        [HideInInspector] _Splat1("Layer 1 (G)", 2D) = "grey" {}
        [HideInInspector] _Splat0("Layer 0 (R)", 2D) = "grey" {}
        [HideInInspector] _Normal3("Normal 3 (A)", 2D) = "bump" {}
        [HideInInspector] _Normal2("Normal 2 (B)", 2D) = "bump" {}
        [HideInInspector] _Normal1("Normal 1 (G)", 2D) = "bump" {}
        [HideInInspector] _Normal0("Normal 0 (R)", 2D) = "bump" {}
        [HideInInspector] _Mask3("Mask 3 (A)", 2D) = "grey" {}
        [HideInInspector] _Mask2("Mask 2 (B)", 2D) = "grey" {}
        [HideInInspector] _Mask1("Mask 1 (G)", 2D) = "grey" {}
        [HideInInspector] _Mask0("Mask 0 (R)", 2D) = "grey" {}
        [HideInInspector][Gamma] _Metallic0("Metallic 0", Range(0.0, 1.0)) = 0.0
        [HideInInspector][Gamma] _Metallic1("Metallic 1", Range(0.0, 1.0)) = 0.0
        [HideInInspector][Gamma] _Metallic2("Metallic 2", Range(0.0, 1.0)) = 0.0
        [HideInInspector][Gamma] _Metallic3("Metallic 3", Range(0.0, 1.0)) = 0.0
        [HideInInspector] _Smoothness0("Smoothness 0", Range(0.0, 1.0)) = 0.5
        [HideInInspector] _Smoothness1("Smoothness 1", Range(0.0, 1.0)) = 0.5
        [HideInInspector] _Smoothness2("Smoothness 2", Range(0.0, 1.0)) = 0.5
        [HideInInspector] _Smoothness3("Smoothness 3", Range(0.0, 1.0)) = 0.5
        
        // used in fallback on old cards & base map
        [HideInInspector] _MainTex("BaseMap (RGB)", 2D) = "grey" {}
        [HideInInspector] _BaseColor("Main Color", Color) = (1,1,1,1)

        [HideInInspector] _TerrainHolesTexture("Holes Map (RGB)", 2D) = "white" {}

        [HideInInspector][ToggleUI] _EnableInstancedPerPixelNormal("Enable Instanced per-pixel normal", Float) = 1.0
    }

    HLSLINCLUDE
    #pragma multi_compile_fragment __ _ALPHATEST_ON
    ENDHLSL

    SubShader
    {
        Tags { "Queue" = "Geometry-100" "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit" "IgnoreProjector" = "False" "TerrainCompatible" = "True"}

    	//ForForwardLit
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            HLSLPROGRAM
            #pragma target 3.0

            #pragma vertex SplatmapVert
            #pragma fragment SplatmapFragment

            #define _METALLICSPECGLOSSMAP 1
            #define _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A 1

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ _LIGHT_LAYERS
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile_fragment _ _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            //#include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
            //#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            #pragma shader_feature_local_fragment _TERRAIN_BLEND_HEIGHT
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local_fragment _MASKMAP
            // Sample normal in pixel shader when doing instancing
            #pragma shader_feature_local _TERRAIN_INSTANCED_PERPIXEL_NORMAL

            #include "CustomTerrainLitInput.hlsl"
            #include "CustomTerrainLitPasses.hlsl"
            ENDHLSL
        }
    	

    	
        //Grass
    	
    	 Pass
        {
        	Name "GrassPass"
	        Cull Off
        	
            HLSLPROGRAM
            
            #pragma vertex vert_Grass
            #pragma hull hull_Grass
            #pragma domain domain_Grass
            #pragma geometry geo_Grass
            #pragma fragment frag_Grass
            
            #pragma multi_compile  _MAIN_LIGHT_SHADOWS
			#pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile  _SHADOWS_SOFT

            #pragma require geometry
    		#pragma require tessellation tessHW

            #pragma shader_feature _Grass1
		    #pragma shader_feature _Grass2
		    #pragma shader_feature _Grass3
		    #pragma shader_feature _Grass4

            #pragma target 4.6
            
           #include "CustomTerrianGrassPass.hlsl"
            
            ENDHLSL
        }
    	
    	//GrassShadow
    	Pass
    	{
    		Name "GrassShadowCaster"
			Tags{ "LightMode" = "ShadowCaster" }

			ZWrite On
			ZTest LEqual

			HLSLPROGRAM

			 #pragma vertex vert_Grass
			#pragma hull hull_Grass
			#pragma domain domain_Grass
			#pragma geometry geo_Grass
			#pragma fragment frag

			#define SHADERPASS_SHADOWCASTER

			#pragma shader_feature_local _ DISTANCE_DETAIL
			#pragma require geometry
			#pragma require tessellation tessHW
			
			#pragma shader_feature _Grass1
		    #pragma shader_feature _Grass2
		    #pragma shader_feature _Grass3
		    #pragma shader_feature _Grass4

			#pragma target 4.6
			
			#include "CustomTerrianGrassPass.hlsl"

			half4 frag(geoOutputGrass input) : SV_TARGET
			{
				return 1;
			 }

			ENDHLSL
        }



    	//ShadowCaster(地形)
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            // -------------------------------------
            // Universal Pipeline keywords

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitPasses.hlsl"
            
            ENDHLSL
        }


    	//GBuffer
        Pass
        {
            Name "GBuffer"
            Tags{"LightMode" = "UniversalGBuffer"}

            HLSLPROGRAM
            #pragma target 4.5

            // Deferred Rendering Path does not support the OpenGL-based graphics API:
            // Desktop OpenGL, OpenGL ES 3.0, WebGL 2.0.
            #pragma exclude_renderers gles3 glcore

            #pragma vertex SplatmapVert
            #pragma fragment SplatmapFragment

            #define _METALLICSPECGLOSSMAP 1
            #define _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A 1

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            //#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            //#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            //#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED

            //#pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            #pragma shader_feature_local _TERRAIN_BLEND_HEIGHT
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _MASKMAP
            // Sample normal in pixel shader when doing instancing
            #pragma shader_feature_local _TERRAIN_INSTANCED_PERPIXEL_NORMAL
            #define TERRAIN_GBUFFER 1

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitPasses.hlsl"
            
            ENDHLSL
        }

    	//DepthOnly
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask R

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitPasses.hlsl"
            
            ENDHLSL
        }

        // DepthNormals
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On

            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex DepthNormalOnlyVertex
            #pragma fragment DepthNormalOnlyFragment

            #pragma shader_feature_local _NORMALMAP
            //#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitDepthNormalsPass.hlsl"
            ENDHLSL
        }

    	//SceneSelectionPass
        Pass
        {
            Name "SceneSelectionPass"
            Tags { "LightMode" = "SceneSelectionPass" }

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            #define SCENESELECTIONPASS
            
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitPasses.hlsl"
            
            ENDHLSL
        }

        // This pass it not used during regular rendering, only for lightmap baking.
        Pass
        {
            Name "Meta"
            Tags{"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            #pragma vertex TerrainVertexMeta
            #pragma fragment TerrainFragmentMeta

            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap
            #pragma shader_feature EDITOR_VISUALIZATION
            #define _METALLICSPECGLOSSMAP 1
            #define _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A 1

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitMetaPass.hlsl"
            ENDHLSL
        }

        UsePass "Hidden/Nature/Terrain/Utilities/PICKING"
    }
    Dependency "AddPassShader" = "Hidden/Universal Render Pipeline/Terrain/Lit (Add Pass)"
    Dependency "BaseMapShader" = "Hidden/Universal Render Pipeline/Terrain/Lit (Base Pass)"
    Dependency "BaseMapGenShader" = "Hidden/Universal Render Pipeline/Terrain/Lit (Basemap Gen)"
	
	CustomEditor "UnityEditor.Rendering.Universal.CustomTerrainGrassShaderGUI"
    
    Fallback "Hidden/Universal Render Pipeline/FallbackError"
}
