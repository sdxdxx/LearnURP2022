using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ColorTintVolume : VolumeComponent
{
    public BoolParameter EnableEffect = new BoolParameter(false, true);
    public  ColorParameter ColorChange = new ColorParameter(Color.white, true);

    public bool IsActive() => EnableEffect.value;
}