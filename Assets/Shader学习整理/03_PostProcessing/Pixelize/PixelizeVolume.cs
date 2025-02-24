using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class PixelizeVolume : VolumeComponent
{
    public  BoolParameter EnablePixelizer = new BoolParameter(false,true);
    public ClampedIntParameter DownSampleValue = new ClampedIntParameter(0,0,5,true);
    public  ColorParameter ColorChange = new ColorParameter(Color.white, true);
}
