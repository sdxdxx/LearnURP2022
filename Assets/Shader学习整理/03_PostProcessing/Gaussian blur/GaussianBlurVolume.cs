using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class GaussianBlurVolume : VolumeComponent
{
    public ColorParameter ColorChange = new ColorParameter(Color.white, true);
    public FloatParameter BlurSize = new ClampedFloatParameter(0,0,5,true);
}
