using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ScreenSpaceReflectionVolume : VolumeComponent
{
    public BoolParameter EnableReflection = new BoolParameter(false,true);
    public BoolParameter ShowReflectionTexture = new BoolParameter(false,true);
    public ColorParameter ColorChange = new ColorParameter(Color.white, true);
    public ClampedFloatParameter StepLength = new ClampedFloatParameter(1f, 0f, 1f);
    public ClampedFloatParameter Bias = new ClampedFloatParameter(0.01f, 0f, 1f);
}
