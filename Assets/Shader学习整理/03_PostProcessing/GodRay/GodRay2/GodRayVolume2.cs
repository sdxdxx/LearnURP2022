using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class GodRayVolume2 : VolumeComponent
{
    public BoolParameter EnableEffect = new BoolParameter(false, true);
    public  ColorParameter ColorChange = new ColorParameter(Color.white, true);
    public ClampedFloatParameter Intensity = new ClampedFloatParameter(0.25f, 0f, 1f);
    public ClampedFloatParameter Scattering = new ClampedFloatParameter(0.25f, 0f, 1f);
    public ClampedIntParameter StepTime = new ClampedIntParameter(16, 8, 64);
    public FloatParameter RandomNumber = new FloatParameter(0);
    public ClampedIntParameter DownSample = new ClampedIntParameter(2, 1, 8);
    public ClampedFloatParameter BlurRange = new ClampedFloatParameter(1, 0, 10);
    public TextureParameter CloudTex = new TextureParameter(value: null);
    public Vector4Parameter CloudTexTillingAndOffset = new Vector4Parameter(new Vector4(1f, 1f, 0f, 0f));
    public Vector2Parameter CloudTexUVFlowSpeed = new Vector2Parameter(new Vector2(0f, 0f));
}
