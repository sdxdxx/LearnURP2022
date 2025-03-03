using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class PixelizeVolume : VolumeComponent
{
    public  BoolParameter EnablePixelizer = new BoolParameter(false,true);
    public ClampedIntParameter DownSampleValue = new ClampedIntParameter(0,0,5,true);
    public  ColorParameter ColorChange = new ColorParameter(Color.white, true);
    public BoolParameter EnableContrastAndSaturation= new BoolParameter(false,true);
    public FloatParameter Contrast = new FloatParameter(0f, true);
    public FloatParameter Saturation = new FloatParameter(0f, true);
    public BoolParameter EnablePoint = new BoolParameter(false,true);
    public ClampedFloatParameter PointIntensity= new ClampedFloatParameter(0f, 0f,1f,true);
}
