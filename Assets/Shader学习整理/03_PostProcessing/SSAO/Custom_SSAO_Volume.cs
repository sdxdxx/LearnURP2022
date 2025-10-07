using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class Custom_SSAO_Volume : VolumeComponent
{
   [Header("开启效果")] 
   public BoolParameter EnableEffect = new BoolParameter(false);
   
   [Header("强度")]
   public FloatParameter Intensity = new ClampedFloatParameter(0.727f,0,2);
   
   [Header("剔除")]
   public FloatParameter CullValue = new ClampedFloatParameter(0.2f,0,0.3f);

   [Header("精度补偿")] 
   public FloatParameter DepthBias = new ClampedFloatParameter(0.00012f,0f,0.0002f);

   [Header("采样数")] 
   public IntParameter SampleCount = new ClampedIntParameter(16, 4, 64);

   [Header("采样半径")] 
   public FloatParameter SampleRadius = new ClampedFloatParameter(0.32f, 0.001f, 2f);
   
   [Header("内采样半径")]
   public FloatParameter InsideRadius = new ClampedFloatParameter(0.08f, 0.001f, 0.2f);

   [Header("开启模糊")] 
   public BoolParameter Blur = new BoolParameter(false);
   
   [Header("模糊半径")]
   public IntParameter BlurRadius = new ClampedIntParameter(2, 1, 4);
   
   [Header("模糊滤波强度")]
   public FloatParameter BilaterFilterStrength = new ClampedFloatParameter(0.003f, 0.00001f, 0.01f);
   
   [Header("仅开启SSAO")]
   public BoolParameter SSAO_Only= new BoolParameter(false);

}
