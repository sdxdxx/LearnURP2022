using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Serialization;

public class CloudsVolume : VolumeComponent
{
    
    //Enable Effect
    public BoolParameter EnableEffect = new BoolParameter(false,true);
    public BoolParameter EnableSkyMask = new BoolParameter(false, true);
    public ClampedFloatParameter SkyMaskValue = new ClampedFloatParameter(0.1f, 0, 1);
    public ClampedIntParameter DownSampleValue = new ClampedIntParameter(1, 1, 8);
    public ClampedFloatParameter BlurRange = new ClampedFloatParameter(1, 0, 1);
    
    public ColorParameter CloudColor = new ColorParameter(Color.white, true);
    public ClampedFloatParameter StepTime= new ClampedFloatParameter(64, 8,512);
    
    //Noise
    public TextureParameter NoiseTex = new TextureParameter(value:null);
    public TextureParameter DetailNoiseTex = new TextureParameter(value:null);
    public TextureParameter MaskNoise = new TextureParameter(value: null);
    public TextureParameter BlueNoise = new TextureParameter(value: null);
    public FloatParameter NoiseTexScale = new FloatParameter(1f);
    public FloatParameter DetailNoiseTexScale = new FloatParameter(1f);
    public Vector3Parameter NoiseTexOffset = new Vector3Parameter(new Vector3(0, 0, 0));
    public Vector4Parameter BlueNoiseTillingOffset = new Vector4Parameter(new Vector4(1f,1f,0f,0f));
    public Vector4Parameter shapeNoiseWeights = new Vector4Parameter(new Vector4(-0.17f, 27.7f, -3.65f, -0.08f));
    public FloatParameter detailWeights = new FloatParameter(-3.76f);
    public FloatParameter detailNoiseWeight = new FloatParameter(0.12f);
    public ClampedFloatParameter rayOffsetStrength = new ClampedFloatParameter(1f, 0f, 5f);

    //Density
    public TextureParameter WeatherMap = new TextureParameter(value:null);
    public FloatParameter WeatherMapScale = new FloatParameter(1);
    public FloatParameter densityOffset = new FloatParameter(4.02f);
    public FloatParameter densityMultiplier = new FloatParameter(1f);
    public ClampedFloatParameter heightWeights = new ClampedFloatParameter(1f,0f,1f);
    
    //Light
    public ColorParameter colA = new ColorParameter(Color.white ,true);
    public ColorParameter colB = new ColorParameter(Color.white ,true);
    public FloatParameter colorOffset1 = new FloatParameter(0.86f);
    public FloatParameter colorOffset2 = new FloatParameter(0.82f);
    public ClampedFloatParameter lightAbsorptionTowardSun = new ClampedFloatParameter(0.16f,0,0.2f);
    
    //散射
    public Vector4Parameter phaseParams = new Vector4Parameter(new Vector4(0.78f, 0.25f, 0.29f, 0.6f));
    
    //气流移动速度
    public Vector2Parameter xy_WeatherSpeed = new Vector2Parameter(new Vector2(0,0));
    public Vector4Parameter xy_Speed_zw_Warp = new Vector4Parameter(new Vector4(0.05f, 0.3f, 0f, 0f));
}
