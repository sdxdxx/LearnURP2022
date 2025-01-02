using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

public class WaterVolume : VolumeComponent
{

    public BoolParameter EnableEffect = new BoolParameter(false, true);
    [Header("UnderWater")]
    public  ColorParameter UnderWaterDeepColor = new ColorParameter(Color.white, true);
    public  ColorParameter UnderWaterShallowColor = new ColorParameter(Color.white, true);

    public TextureParameter DistorationNoise = new TextureParameter(value: null);
    public Vector2Parameter DistorationNoise_Tilling = new Vector2Parameter(new Vector2(1, 1));
    public ClampedFloatParameter DistorationIntensity = new ClampedFloatParameter(0.5f, 0, 1);
    public FloatParameter DistorationSpeed = new FloatParameter(1f);

    [Header("Caustics")] 
    public TextureParameter CausticsTexture = new TextureParameter(value: null);
    public FloatParameter CausticsTextureScale = new FloatParameter(1f);
    public FloatParameter CausiticsSpeed = new FloatParameter(1f);
    public ClampedFloatParameter CausiticsIntensity = new ClampedFloatParameter(1f, 0f, 1f);
    
    [Header("Wave (Dir, Steepness, WaveLength)")]
    public Vector4Parameter WaveA = new Vector4Parameter(new Vector4(0.2f, 0f, 0.1f, 2f));
    public Vector4Parameter WaveB = new Vector4Parameter(new Vector4(0f, 0.2f, 0.05f, 2f));
    public Vector4Parameter WaveC = new Vector4Parameter(new Vector4(0.2f, 0.2f, 0.1f, 2f));
    public ClampedFloatParameter WaveInt = new ClampedFloatParameter(1f, 0f, 1f);
    
    [Header("WaterLine")]
    public ClampedFloatParameter WaterLineWidth = new ClampedFloatParameter(5, 0, 10);
    public ClampedFloatParameter WaterLineSmooth = new ClampedFloatParameter(0.5f, 0, 1);
    [FormerlySerializedAs("UnderWaterLineOffset")] public ClampedFloatParameter WaterLineOffset = new ClampedFloatParameter(0, 0, 2);
    public  ColorParameter WaterLineColor = new ColorParameter(Color.white, true);
    
}
