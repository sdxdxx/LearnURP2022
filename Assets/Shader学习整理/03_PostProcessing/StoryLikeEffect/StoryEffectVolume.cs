using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

public class StoryEffectVolume : VolumeComponent
{
    public BoolParameter EnbaleStoryEffect = new BoolParameter(false,true);
    public ColorParameter ColorChange = new ColorParameter(Color.white, true);
    public ColorParameter VignetteColor = new ColorParameter(Color.white, true);
    public TextureParameter PaperMaskTexture = new TextureParameter(null);
    public TextureParameter PaperMaskNoise = new TextureParameter(null);
    public TextureParameter VignetteMask = new TextureParameter(null);
    public TextureParameter PaperEffectTexture = new TextureParameter(null);
    public Vector4Parameter PaperEffectTillingAndOffset = new Vector4Parameter(new Vector4(3.0f, 3.0f, 0.0f, 0.0f));
    public ClampedFloatParameter PaperMaskEdgeWidth = new ClampedFloatParameter(0.83f,0,1);
    public ClampedFloatParameter PaperMaskEdgeFlowSpeed = new ClampedFloatParameter(0.5f,0,1);
    public ClampedFloatParameter PaperEffectIntensity = new ClampedFloatParameter(3f,0,5);
    public ClampedFloatParameter VignetteIntensity = new ClampedFloatParameter(0.5f,0,1);
    public ClampedFloatParameter TestValue = new ClampedFloatParameter(1.0f,0,1);
}
