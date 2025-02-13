using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ScreenSpaceReflectionVolume : VolumeComponent
{
    public enum ScreenSpaceReflectionType
    {
        Simple_ViewSpace = 1,
        BinarySearch_ViewSpace,
        BinarySearch_Jitter_ViewSpace,
        Efficient_ScreenSpace,
        Efficient_ScreenSpace_Jitter,
        HIZ_ViewSpace
    }
    
    public ScreenSpaceReflectionTypeParameter ScreenSpaceReflectionMode= new ScreenSpaceReflectionTypeParameter(ScreenSpaceReflectionType.Simple_ViewSpace);
    
    //Universal
    public BoolParameter EnableReflection = new BoolParameter(false,true);
    public BoolParameter ShowReflectionTexture = new BoolParameter(false,true);
    public ColorParameter ColorChange = new ColorParameter(Color.white, true);
    
    //Simple
    public ClampedFloatParameter StepLength = new ClampedFloatParameter(0.05f, 0f, 1f);
    public ClampedFloatParameter Thickness = new ClampedFloatParameter(0.1f, 0f, 1f);
    
    //BinarySearch
    public ClampedFloatParameter MaxStepLength = new ClampedFloatParameter(0.1f, 0f, 5f);
    public ClampedFloatParameter MinDistance = new ClampedFloatParameter(0.02f, 0f, 1f);
    
    //Efficient
    public ClampedFloatParameter MaxReflectLength = new ClampedFloatParameter(1f, 0f, 100f);
    public ClampedIntParameter DeltaPixel = new ClampedIntParameter(1, 1, 50);
    
    //Jitter Dither
    public ClampedFloatParameter DitherIntensity = new ClampedFloatParameter(1f, 0f, 5f);
    
    [Serializable]
    public sealed class ScreenSpaceReflectionTypeParameter : VolumeParameter<ScreenSpaceReflectionVolume.ScreenSpaceReflectionType>
    {
        public ScreenSpaceReflectionTypeParameter(ScreenSpaceReflectionVolume.ScreenSpaceReflectionType value, bool overrideState = true)
            : base(value, overrideState) { }
    }
    
}


