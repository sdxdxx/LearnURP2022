using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ScreenSpaceSSS_SkinVolume : VolumeComponent
{
    public  ColorParameter SSSColor = new ColorParameter(Color.white, true);
    public ClampedFloatParameter SSSIntensity = new ClampedFloatParameter(1, 0, 5);
    public FloatParameter BlurRadius = new FloatParameter(1);
    public ClampedIntParameter Iteration = new ClampedIntParameter(1, 0, 8);
}
