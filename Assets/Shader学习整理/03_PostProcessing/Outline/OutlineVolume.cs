using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class OutlineVolume : VolumeComponent
{
    public  ColorParameter OutlineColor = new ColorParameter(Color.white, true);
    public FloatParameter Rate = new FloatParameter(0);
}
